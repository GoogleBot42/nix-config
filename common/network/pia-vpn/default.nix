{ config, lib, pkgs, ... }:

# PIA VPN multi-container module.
#
# Architecture:
#   Host creates WG interface, runs tinyproxy on bridge for PIA API bootstrap.
#   VPN container does all PIA logic via proxy, configures WG, masquerades bridge→piaw.
#   Service containers default route → VPN container (leak-proof by topology).
#
# Reference: https://www.wireguard.com/netns/#ordinary-containerization

with lib;

let
  cfg = config.pia-vpn;

  # Derive prefix length from subnet CIDR (e.g. "10.100.0.0/24" → "24")
  subnetPrefixLen = last (splitString "/" cfg.subnet);

  containerSubmodule = types.submodule ({ name, ... }: {
    options = {
      ip = mkOption {
        type = types.str;
        description = "Static IP address for this container on the VPN bridge";
      };

      config = mkOption {
        type = types.anything;
        default = { };
        description = "NixOS configuration for this container";
      };

      mounts = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            hostPath = mkOption {
              type = types.str;
              description = "Path on the host to bind mount";
            };
            isReadOnly = mkOption {
              type = types.bool;
              default = false;
              description = "Whether the mount is read-only";
            };
          };
        });
        default = { };
        description = "Bind mounts for the container";
      };

      receiveForwardedPort = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            port = mkOption {
              type = types.nullOr types.port;
              default = null;
              description = ''
                Target port to forward to. If null, forwards to the same PIA-assigned port.
                PIA-assigned ports below 10000 are rejected to avoid accidentally
                forwarding traffic to other services.
              '';
            };
            protocol = mkOption {
              type = types.enum [ "tcp" "udp" "both" ];
              default = "both";
              description = "Protocol(s) to forward";
            };
          };
        });
        default = null;
        description = "Port forwarding configuration. At most one container may set this.";
      };

      onPortForwarded = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = ''
          Optional script run in the VPN container after port forwarding is established.
          Available environment variables: $PORT (PIA-assigned port), $TARGET_IP (this container's IP).
        '';
      };
    };
  });

  # NOTE: All derivations of cfg.containers are kept INSIDE config = mkIf ... { }
  # to avoid infinite recursion. The module system's pushDownProperties eagerly
  # evaluates let bindings and mkMerge contents, so any top-level let binding
  # that touches cfg.containers would force config evaluation during structure
  # discovery, creating a cycle.
in
{
  imports = [
    ./vpn-container.nix
    ./service-container.nix
  ];

  options.pia-vpn = {
    enable = mkEnableOption "PIA VPN multi-container setup";

    serverLocation = mkOption {
      type = types.str;
      default = "swiss";
      description = "PIA server region ID";
    };

    interfaceName = mkOption {
      type = types.str;
      default = "piaw";
      description = "WireGuard interface name";
    };

    wireguardListenPort = mkOption {
      type = types.port;
      default = 51820;
      description = "WireGuard listen port";
    };

    bridgeName = mkOption {
      type = types.str;
      default = "br-vpn";
      description = "Bridge interface name for VPN containers";
    };

    subnet = mkOption {
      type = types.str;
      default = "10.100.0.0/24";
      description = "Subnet CIDR for VPN bridge network";
    };

    hostAddress = mkOption {
      type = types.str;
      default = "10.100.0.1";
      description = "Host IP on the VPN bridge";
    };

    vpnAddress = mkOption {
      type = types.str;
      default = "10.100.0.2";
      description = "VPN container IP on the bridge";
    };

    proxyPort = mkOption {
      type = types.port;
      default = 8888;
      description = "Tinyproxy port for PIA API bootstrap";
    };

    containers = mkOption {
      type = types.attrsOf containerSubmodule;
      default = { };
      description = "Service containers that route through the VPN";
    };

    # Subnet prefix length derived from cfg.subnet (exposed for other submodules)
    subnetPrefixLen = mkOption {
      type = types.str;
      default = subnetPrefixLen;
      description = "Prefix length derived from subnet CIDR";
      readOnly = true;
    };

    # Shared host entries for all containers (host + VPN + service containers)
    containerHosts = mkOption {
      type = types.attrsOf (types.listOf types.str);
      internal = true;
      readOnly = true;
    };
  };

  config = mkIf cfg.enable {
    assertions =
      let
        forwardingContainers = filterAttrs (_: c: c.receiveForwardedPort != null) cfg.containers;
        containerIPs = mapAttrsToList (_: c: c.ip) cfg.containers;
      in
      [
        {
          assertion = length (attrNames forwardingContainers) <= 1;
          message = "At most one pia-vpn container may set receiveForwardedPort";
        }
        {
          assertion = length containerIPs == length (unique containerIPs);
          message = "pia-vpn container IPs must be unique";
        }
      ];

    # Enable systemd-networkd for bridge management
    systemd.network.enable = true;

    systemd.network.wait-online.anyInterface = true;

    # Tell NetworkManager to ignore VPN bridge and container interfaces
    networking.networkmanager.unmanaged = mkIf config.networking.networkmanager.enable [
      "interface-name:${cfg.bridgeName}"
      "interface-name:ve-*"
    ];

    # Bridge network device
    systemd.network.netdevs."20-${cfg.bridgeName}".netdevConfig = {
      Kind = "bridge";
      Name = cfg.bridgeName;
    };

    # Bridge network configuration — NO IPMasquerade (host must NOT be gateway)
    systemd.network.networks."20-${cfg.bridgeName}" = {
      matchConfig.Name = cfg.bridgeName;
      networkConfig = {
        Address = "${cfg.hostAddress}/${cfg.subnetPrefixLen}";
        DHCPServer = false;
      };
      linkConfig.RequiredForOnline = "no";
    };

    networking.firewall = mkMerge [
      {
        # Allow wireguard traffic through rpfilter
        checkReversePath = "loose";

        # Allow tinyproxy from bridge (tinyproxy itself restricts to VPN container IP)
        interfaces.${cfg.bridgeName}.allowedTCPPorts = [ cfg.proxyPort ];
      }

      # Block bridge → outside forwarding (prevents host from being a gateway for
      # containers). extraForwardRules only exists on the nftables backend and is
      # silently ignored with iptables, so an iptables fallback is required.
      (mkIf config.networking.nftables.enable {
        extraForwardRules = ''
          iifname "${cfg.bridgeName}" oifname != "${cfg.bridgeName}" drop
        '';
      })
      (mkIf (!config.networking.nftables.enable) {
        extraCommands = ''
          ip46tables -D FORWARD -i ${cfg.bridgeName} ! -o ${cfg.bridgeName} -j DROP 2>/dev/null || true
          ip46tables -I FORWARD -i ${cfg.bridgeName} ! -o ${cfg.bridgeName} -j DROP
        '';
        extraStopCommands = ''
          ip46tables -D FORWARD -i ${cfg.bridgeName} ! -o ${cfg.bridgeName} -j DROP 2>/dev/null || true
        '';
      })
    ];

    # Tinyproxy — runs on bridge IP so VPN container can bootstrap PIA auth.
    # Allow ONLY the VPN container: without an Allow directive tinyproxy accepts
    # all clients, which would let service containers bypass the VPN through the
    # proxy with the host's real IP.
    services.tinyproxy = {
      enable = true;
      settings = {
        Listen = cfg.hostAddress;
        Port = cfg.proxyPort;
        Allow = cfg.vpnAddress;
      };
    };
    systemd.services.tinyproxy = {
      before = [ "container@pia-vpn.service" ];
      after = [ "systemd-networkd.service" ];
      requires = [ "systemd-networkd.service" ];
      serviceConfig = {
        ExecStartPre = [
          "+${pkgs.systemd}/lib/systemd/systemd-networkd-wait-online --interface=${cfg.bridgeName}:no-carrier --timeout=180"
        ];
        # Keep systemd's service start timeout above wait-online's bridge wait,
        # otherwise systemd kills tinyproxy before the explicit 180s readiness
        # check can finish on slow boots.
        TimeoutStartSec = "200s";
      };
    };

    # Host entries for container hostnames — NixOS only auto-creates these for
    # hostAddress/localAddress containers, not hostBridge. Use the standard
    # {name}.containers convention.
    pia-vpn.containerHosts =
      { ${cfg.vpnAddress} = [ "pia-vpn.containers" ]; }
      // mapAttrs' (name: ctr: nameValuePair ctr.ip [ "${name}.containers" ]) cfg.containers;

    networking.hosts = cfg.containerHosts;

    # PIA login secret
    age.secrets."pia-login.conf".file = ../../../secrets/pia-login.age;

    # IP forwarding needed for bridge traffic between containers
    networking.ip_forward = true;
  };
}

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
              type = types.port;
              description = "Target port to forward PIA-assigned port to";
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

    # TODO: re-enable once primary networking uses networkd
    systemd.network.wait-online.enable = false;

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

    # Allow wireguard traffic through rpfilter
    networking.firewall.checkReversePath = "loose";

    # Block bridge → outside forwarding (prevents host from being a gateway for containers)
    networking.firewall.extraForwardRules = ''
      iifname "${cfg.bridgeName}" oifname != "${cfg.bridgeName}" drop
    '';

    # Allow tinyproxy from bridge (tinyproxy itself restricts to VPN container IP)
    networking.firewall.interfaces.${cfg.bridgeName}.allowedTCPPorts = [ cfg.proxyPort ];

    # Tinyproxy — runs on bridge IP so VPN container can bootstrap PIA auth
    services.tinyproxy = {
      enable = true;
      settings = {
        Listen = cfg.hostAddress;
        Port = cfg.proxyPort;
      };
    };
    systemd.services.tinyproxy.before = [ "container@pia-vpn.service" ];

    # WireGuard interface creation (host-side oneshot)
    # Creates the interface in the host namespace so encrypted UDP stays in host netns.
    # The container takes ownership of the interface on startup via `interfaces = [ ... ]`.
    systemd.services.pia-vpn-wg-create = {
      description = "Create PIA VPN WireGuard interface";

      before = [ "container@pia-vpn.service" ];
      requiredBy = [ "container@pia-vpn.service" ];
      partOf = [ "container@pia-vpn.service" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ iproute2 ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        [[ -z $(ip link show dev ${cfg.interfaceName} 2>/dev/null) ]] || exit 0
        ip link add ${cfg.interfaceName} type wireguard
      '';

      preStop = ''
        ip link del ${cfg.interfaceName} 2>/dev/null || true
      '';
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

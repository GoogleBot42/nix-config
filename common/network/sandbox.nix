{ config, lib, ... }:

# Network configuration for sandboxed workspaces (VMs and containers)
# Creates a bridge network with NAT for isolated environments

with lib;

let
  cfg = config.networking.sandbox;
in
{
  options.networking.sandbox = {
    enable = mkEnableOption "sandboxed workspace network bridge";

    bridgeName = mkOption {
      type = types.str;
      default = "sandbox-br";
      description = "Name of the bridge interface for sandboxed workspaces";
    };

    subnet = mkOption {
      type = types.str;
      default = "192.168.83.0/24";
      description = "Subnet for sandboxed workspace network";
    };

    hostAddress = mkOption {
      type = types.str;
      default = "192.168.83.1";
      description = "Host address on the sandbox bridge";
    };

    upstreamInterface = mkOption {
      type = types.str;
      description = "Upstream network interface for NAT";
    };
  };

  config = mkIf cfg.enable {
    networking.ip_forward = true;

    # Create the bridge interface
    systemd.network.netdevs."10-${cfg.bridgeName}" = {
      netdevConfig = {
        Kind = "bridge";
        Name = cfg.bridgeName;
      };
    };

    systemd.network.networks."10-${cfg.bridgeName}" = {
      matchConfig.Name = cfg.bridgeName;
      networkConfig = {
        Address = "${cfg.hostAddress}/24";
        DHCPServer = false;
        IPv4Forwarding = true;
        IPv6Forwarding = false;
        IPMasquerade = "ipv4";
      };
      linkConfig.RequiredForOnline = "no";
    };

    # Automatically attach VM tap interfaces to the bridge
    systemd.network.networks."11-vm" = {
      matchConfig.Name = "vm-*";
      networkConfig.Bridge = cfg.bridgeName;
      linkConfig.RequiredForOnline = "no";
    };

    # Automatically attach container veth interfaces to the bridge
    systemd.network.networks."11-container" = {
      matchConfig.Name = "ve-*";
      networkConfig.Bridge = cfg.bridgeName;
      linkConfig.RequiredForOnline = "no";
    };

    # NAT configuration for sandboxed workspaces
    networking.nat = {
      enable = true;
      internalInterfaces = [ cfg.bridgeName ];
      externalInterface = cfg.upstreamInterface;
    };

    # Enable systemd-networkd (required for bridge setup)
    systemd.network.enable = true;

    # When NetworkManager handles primary networking, disable systemd-networkd-wait-online.
    # The bridge is the only interface managed by systemd-networkd and it never reaches
    # "online" state without connected workspaces. NetworkManager-wait-online.service already
    # gates network-online.target for the primary interface.
    # On pure systemd-networkd systems (no NM), we just ignore the bridge.
    systemd.network.wait-online.enable =
      !config.networking.networkmanager.enable;
    systemd.network.wait-online.ignoredInterfaces =
      lib.mkIf (!config.networking.networkmanager.enable) [ cfg.bridgeName ];

    # If NetworkManager is enabled, tell it to ignore sandbox interfaces
    # This allows systemd-networkd and NetworkManager to coexist
    networking.networkmanager.unmanaged = [
      "interface-name:${cfg.bridgeName}"
      "interface-name:vm-*"
      "interface-name:ve-*"
      "interface-name:veth*"
    ];

    # Make systemd-resolved listen on the bridge for workspace DNS queries.
    # By default resolved only listens on 127.0.0.53 (localhost).
    # DNSStubListenerExtra adds the bridge address so workspaces can use the host as DNS.
    services.resolved.settings.Resolve.DNSStubListenerExtra = cfg.hostAddress;

    # Allow DNS traffic from workspaces to the host
    networking.firewall.interfaces.${cfg.bridgeName} = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    # Block sandboxes from reaching the local network (private RFC1918 ranges)
    # while still allowing public internet access via NAT.
    # The sandbox subnet itself is allowed so workspaces can reach the host gateway.
    networking.firewall.extraForwardRules = ''
      iifname ${cfg.bridgeName} ip daddr ${cfg.hostAddress} accept
      iifname ${cfg.bridgeName} ip daddr 10.0.0.0/8 drop
      iifname ${cfg.bridgeName} ip daddr 172.16.0.0/12 drop
      iifname ${cfg.bridgeName} ip daddr 192.168.0.0/16 drop
    '';
  };
}

{ config, lib, allModules, ... }:

# Generates service containers that route all traffic through the VPN container.
# Each container gets a static IP on the VPN bridge with default route → VPN container.
#
# Uses lazy mapAttrs inside fixed config keys to avoid infinite recursion.
# (mkMerge + mapAttrsToList at the top level forces eager evaluation of cfg.containers
# during module structure discovery, which creates a cycle with config evaluation.)

with lib;

let
  cfg = config.pia-vpn;

  mkContainer = name: ctr: {
    autoStart = true;
    ephemeral = true;
    privateNetwork = true;
    hostBridge = cfg.bridgeName;

    bindMounts = mapAttrs
      (_: mount: {
        hostPath = mount.hostPath;
        isReadOnly = mount.isReadOnly;
      })
      ctr.mounts;

    config = { config, pkgs, lib, ... }: {
      imports = allModules ++ [ ctr.config ];

      # Static IP with gateway pointing to VPN container
      networking.useNetworkd = true;
      systemd.network.enable = true;
      networking.useDHCP = false;

      systemd.network.networks."20-eth0" = {
        matchConfig.Name = "eth0";
        networkConfig = {
          Address = "${ctr.ip}/${cfg.subnetPrefixLen}";
          Gateway = cfg.vpnAddress;
          DNS = [ cfg.vpnAddress ];
        };
      };

      networking.hosts = cfg.containerHosts;

      # DNS through VPN container (queries go through WG tunnel = no DNS leak)
      networking.nameservers = [ cfg.vpnAddress ];

      # Trust the bridge interface (host reaches us directly for nginx)
      networking.firewall.trustedInterfaces = [ "eth0" ];

      # Disable host resolv.conf — we use our own networkd DNS config
      networking.useHostResolvConf = false;
    };
  };

  mkContainerOrdering = name: _ctr: nameValuePair "container@${name}" {
    after = [ "container@pia-vpn.service" ];
    requires = [ "container@pia-vpn.service" ];
    partOf = [ "container@pia-vpn.service" ];
  };
in
{
  config = mkIf cfg.enable {
    containers = mapAttrs mkContainer cfg.containers;
    systemd.services = mapAttrs' mkContainerOrdering cfg.containers;
  };
}

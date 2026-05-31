{ config, lib, ... }:

with lib;

let
  cfg = config.networking;
in
{
  imports = [
    ./pia-vpn
    ./tailscale.nix
    ./sandbox.nix
  ];

  options.networking.ip_forward = mkEnableOption "Enable ip forwarding";

  config = mkMerge [
    (mkIf cfg.ip_forward {
      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
      boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
    })

    # Keep dhcpcd away from container/virtual interfaces. dhcpcd runs as a single
    # daemon over every interface not on its deny list, and the nixpkgs default
    # omits these. When containers create/tear down podman0/veth*, dhcpcd reacts
    # to the link events with a full reconfigure and can drop the primary
    # interface's DHCP default route, leaving the host unreachable.
    {
      networking.dhcpcd.denyInterfaces = [
        "podman*"
        "veth*"
        "cni*"
        "docker*"
        "br-*"
      ];
    }
  ];
}

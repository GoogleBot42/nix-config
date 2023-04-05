{ config, lib, ... }:

with lib;

let
  cfg = config.networking;
in
{
  imports = [
    ./hosts.nix
    ./pia-openvpn.nix
    ./pia-wireguard.nix
    ./ping.nix
    ./tailscale.nix
    ./vpn.nix
  ];

  options.networking.ip_forward = mkEnableOption "Enable ip forwarding";

  config = mkIf cfg.ip_forward {
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  };
}

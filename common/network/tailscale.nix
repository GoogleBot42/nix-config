{ config, lib, ... }:

with lib;

let
  cfg = config.services.tailscale;
in
{
  options.services.tailscale.exitNode = mkEnableOption "Enable exit node support";

  config.services.tailscale.enable = mkDefault (!config.boot.isContainer);

  # Trust Tailscale interface - access control is handled by Tailscale ACLs.
  # Required because nftables (used by Incus) breaks Tailscale's automatic iptables rules.
  config.networking.firewall.trustedInterfaces = mkIf cfg.enable [ "tailscale0" ];

  # MagicDNS
  config.networking.nameservers = mkIf cfg.enable [ "1.1.1.1" "8.8.8.8" ];
  config.networking.search = mkIf cfg.enable [ "koi-bebop.ts.net" ];

  # exit node
  config.networking.firewall.checkReversePath = mkIf cfg.exitNode "loose";
  config.networking.ip_forward = mkIf cfg.exitNode true;
}

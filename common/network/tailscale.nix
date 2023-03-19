{ config, lib, ... }:

with lib;

let
  cfg = config.services.tailscale;
in
{
  options.services.tailscale.exitNode = mkEnableOption "Enable exit node support";

  config.services.tailscale.enable = mkDefault (!config.boot.isContainer);

  # MagicDNS
  config.networking.nameservers = mkIf cfg.enable [ "1.1.1.1" "8.8.8.8" "100.100.100.100" ];
  config.networking.search = mkIf cfg.enable [ "koi-bebop.ts.net" ];

  # exit node
  config.networking.firewall.checkReversePath = mkIf cfg.exitNode "loose";
  config.networking.ip_forward = mkIf cfg.exitNode true;
}
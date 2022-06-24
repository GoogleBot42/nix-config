{ config, lib, ... }:

with lib;

let
  cfg = config.services.tailscale;
in
{
  options.services.tailscale.exitNode = mkEnableOption "Enable exit node support";

  config.services.tailscale.enable = !config.boot.isContainer;

  # exit node
  config.networking.firewall.checkReversePath = mkIf cfg.exitNode "loose";
  config.networking.ip_forward = mkIf cfg.exitNode true;
}
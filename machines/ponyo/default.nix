{ config, pkgs, lib, ... }:

# Fully migrated to kif; kept powered as a rollback vault until
# decommission (phase 7). Runs no services.

{
  imports = [
    ./hardware-configuration.nix
  ];

  # system.autoUpgrade.enable = true;

  # p2p mesh network
  services.tailscale.exitNode = true;

  # Tailscale-only nginx virtual hosts bind to ponyo's stable tailnet address.
  services.nginx.tailscaleListenAddress = "100.76.85.13";

  # Keep public web listeners open overall, but pin selected vhosts to the tailnet address.

}

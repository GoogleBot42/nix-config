{ config, pkgs, lib, ... }:

# Being migrated to kif in phases. Phases 2-5 moved everything except the
# mailserver (phase 6), after which this machine is decommissioned.

{
  imports = [
    ./hardware-configuration.nix
  ];

  # system.autoUpgrade.enable = true;

  # p2p mesh network
  services.tailscale.exitNode = true;

  # Tailscale-only nginx virtual hosts bind to ponyo's stable tailnet address.
  services.nginx.tailscaleListenAddress = "100.76.85.13";

  # email server
  mailserver.enable = true;

  # proxied web services
  services.nginx.enable = true;

  # Keep public web listeners open overall, but pin selected vhosts to the tailnet address.

}

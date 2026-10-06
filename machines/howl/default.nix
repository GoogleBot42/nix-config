{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # don't use remote builders
  nix.distributedBuilds = lib.mkForce false;

  # DNS must not go through openresolv here: its resolvconf shell script
  # deadlocks against nscd and tailscaled's DNS lock on every wifi link
  # change, stalling each disconnect, reconnect and suspend by ~10s.
  # resolved is driven over D-Bus by both NetworkManager and tailscaled.
  services.resolved.enable = true;
}

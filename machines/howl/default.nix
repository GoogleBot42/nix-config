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

  # wpa_supplicant 2.11 cannot handle Wi-Fi 7 multi-link (MLO) against the
  # eero APs: FT "roams" to the AP it is already on fail to install keys and
  # 4-way handshakes time out after association. iwd connects single-link.
  networking.networkmanager.wifi.backend = "iwd";
}

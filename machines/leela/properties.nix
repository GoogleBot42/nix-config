{
  hostNames = [
    "leela"
    "openwrt.lan"
  ];

  arch = "aarch64-linux";

  systemRoles = [
    "router"
  ];

  # Converted from the current OpenWrt Dropbear Ed25519 host key backup.
  # Replace this after installing NixOS if the host key is regenerated.
  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMb3IqiAC4CETtJdG0Gszr5y31THW1z0RC5SeyY0mirx";
}

{
  hostNames = [
    "leela"
    "openwrt.lan"
    "192.168.1.1"
  ];

  arch = "aarch64-linux";

  systemRoles = [
    "router"
    # "server" grants the secrets every machine needs (e.g. attic-netrc for the
    # private binary cache, which common/binary-cache.nix references
    # unconditionally). Run `make rekey-secrets` after merging so the secrets
    # are re-encrypted to include this host key.
    "server"
  ];

  # Converted from the current OpenWrt Dropbear Ed25519 host key backup.
  # Replace this after installing NixOS if the host key is regenerated.
  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMb3IqiAC4CETtJdG0Gszr5y31THW1z0RC5SeyY0mirx";
}

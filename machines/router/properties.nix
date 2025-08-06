{
  hostNames = [
    "router"
    "192.168.6.159"
    "192.168.3.1"
  ];

  arch = "x86_64-linux";

  systemRoles = [
    "server"
    "wireless"
    "router"
  ];

  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKDCMhEvWJxFBNyvpyuljv5Uun8AdXCxBK9HvPBRe5x6";
}

{
  hostNames = [
    "s0"
  ];

  arch = "x86_64-linux";

  systemRoles = [
    "storage"
    "server"
    "pia"
    "binary-cache"
    "gitea-actions-runner"
  ];

  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAwiXcUFtAvZCayhu4+AIcF+Ktrdgv9ee/mXSIhJbp4q";

  remoteUnlock = {
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNiceeFMos5ZXcYem4yFxh8PiZNNnuvhlyLbQLrgIZH";
    onionHost = "r3zvf7f2ppaeithzswigma46pajt3hqytmkg3rshgknbl3jbni455fqd.onion";
  };
}

{
  hostNames = [
    "phil"
    "phil.neet.dev"
  ];

  arch = "aarch64-linux";

  systemRoles = [
    "server"
    "gitea-runner"
  ];

  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBlgRPpuUkZqe8/lHugRPm/m2vcN9psYhh5tENHZt9I2";

  remoteUnlock = {
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0RodotOXLMy/w70aa096gaNqPBnfgiXR5ZAH4+wGzd";
    clearnetHost = "unlock.phil.neet.dev";
  };
}

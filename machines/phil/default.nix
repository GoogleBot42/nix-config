{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "phil";

  services.gitea-actions-runner.instances.inst = {
    enable = true;
    name = config.networking.hostName;
    url = "https://git.neet.dev/";
    tokenFile = "/run/agenix/gitea-actions-runner-token";
    labels = [
      "debian-latest:docker://catthehacker/ubuntu:act-latest"
      "ubuntu-latest:docker://catthehacker/ubuntu:act-latest"
    ];
  };
  virtualisation.docker.enable = true;
  age.secrets.gitea-actions-runner-token.file = ../../secrets/gitea-actions-runner-token.age;
}

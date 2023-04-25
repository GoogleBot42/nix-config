{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  services.gitea-runner = {
    enable = true;
    instanceUrl = "https://git.neet.dev";
  };
}

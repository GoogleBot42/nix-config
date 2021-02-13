{ config, pkgs, ... }:

{
  imports = [
    ./flakes.nix
  ];

  boot.loader.timeout = 2;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ ];

  environment.systemPackages = with pkgs; [
    wget kakoune htop git
  ];

  users.mutableUsers = false;
  users.users.googlebot = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMVR/R3ZOsv7TZbICGBCHdjh1NDT8SnswUyINeJOC7QG"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0dcqL/FhHmv+a1iz3f9LJ48xubO7MZHy35rW9SZOYM"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0VFnn3+Mh0nWeN92jov81qNE9fpzTAHYBphNoY7HUx"
    ];
    hashedPassword = "$6$TuDO46rILr$gkPUuLKZe3psexhs8WFZMpzgEBGksE.c3Tjh1f8sD0KMC4oV89K2pqAABfl.Lpxu2jVdr5bgvR5cWnZRnji/r/";
  };
}

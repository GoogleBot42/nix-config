{ config, pkgs, ... }:

{
  programs.steam.enable = true;
  hardware.steam-hardware.enable = true; # steam controller

  users.users.googlebot.packages = [
    pkgs.steam
  ];
}
{ config, pkgs, ... }:

{
  users.users.googlebot.packages = [
    pkgs.discord
  ];
}
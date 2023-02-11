{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "router";

  services.zerotierone.enable = true;

  system.autoUpgrade.enable = true;

  networking.useDHCP = lib.mkForce true;
}
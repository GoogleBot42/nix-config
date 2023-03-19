{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "router";

  system.autoUpgrade.enable = true;

  services.tailscale.exitNode = true;

  networking.useDHCP = lib.mkForce true;
}
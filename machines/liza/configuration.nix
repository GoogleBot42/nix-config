{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  system.autoUpgrade.enable = true;

  networking.hostName = "liza";

  networking.interfaces.enp1s0.useDHCP = true;
}

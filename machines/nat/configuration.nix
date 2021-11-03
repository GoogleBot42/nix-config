{ config, pkgs, fetchurl, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.flakes.enable = true;

  efi.enable = true;

  networking.hostName = "nat";
  networking.interfaces.ens160.useDHCP = true;

  services.zerotierone.enable = true;

  de.enable = true;
  de.touchpad.enable = true;
}

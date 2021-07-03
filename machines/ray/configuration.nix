{ config, pkgs, fetchurl, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.flakes.enable = true;

  efi.enable = true;

  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/d71ebe1f-7c49-454d-b28b-1dc54cf280e5";
    allowDiscards = true;
  };

  networking.hostName = "ray";

  services.zerotierone.enable = true;

  de.enable = true;
  de.touchpad.enable = true;
}

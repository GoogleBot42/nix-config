{ config, pkgs, fetchurl, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common/common.nix
    ../common/efi.nix
    ../common/luks.nix
    ../common/pc/de.nix
    ../common/pc/touchpad.nix
  ];

  networking.hostName = "reg";
  boot.initrd.luks.devices.enc-pv = {
    device = "/dev/disk/by-uuid/975d8427-2c6a-440d-a1d2-18dd15ba5bc2";
    allowDiscards = true;
  };

  networking.useDHCP = false;
  networking.interfaces.enp57s0f1.useDHCP = true;
  networking.interfaces.wlp0s20f3.useDHCP = true;
  networking.interfaces.wwp0s20f0u2i12.useDHCP = true;

  system.stateVersion = "20.09";
}


{ config, pkgs, fetchurl, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # smcxui7kwoyxpswwage4fkcppxnqzpw33xcmxmlhxvk5gcp5s6lrtfad.onion

  boot.kernelPackages = pkgs.linuxPackages_5_12;

  nix.flakes.enable = true;

  efi.enable = true;

  luks = {
    enable = true;
    device = {
      path = "/dev/disk/by-uuid/975d8427-2c6a-440d-a1d2-18dd15ba5bc2";
      allowDiscards = true;
    };
  };

  networking.hostName = "reg";

  de.enable = true;
  de.touchpad.enable = true;

  # VNC
  networking.firewall.allowedTCPPorts = [ 5900 ];

  networking.interfaces.enp57s0f1.useDHCP = true;
}


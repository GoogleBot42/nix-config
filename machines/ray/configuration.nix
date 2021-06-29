{ config, pkgs, fetchurl, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # 2plyinzleibb3r2jfdrzsfflwxsimdfipw2ynbfuueuvydeigwxu2kid.onion

  boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.flakes.enable = true;

  efi.enable = true;

  # luks = {
  #   enable = true;
  #   device = {
  #     path = "/dev/disk/by-uuid/fbe946d3-414f-4c2e-bb24-b845870fde6c";
  #     allowDiscards = true;
  #   };
  # };

  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/fbe946d3-414f-4c2e-bb24-b845870fde6c";
    allowDiscards = true;
  };

  networking.hostName = "ray";

  de.enable = true;
  de.touchpad.enable = true;
}


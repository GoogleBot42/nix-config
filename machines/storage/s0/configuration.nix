{ config, pkgs, lib, ... }:

{
  imports =[
    ./helios64
  ];

  # nsw2zwifzyl42mbhabayjo42b2kkq3wd3dqyl6efxsz6pvmgm5cup5ad.onion

  nix.flakes.enable = true;

  networking.hostName = "s0";

  luks = {
    enable = true;
    device = {
      path = "/dev/disk/by-uuid/96b216e1-071b-4c02-899e-29e2eeced7a8";
      allowDiscards = true;
    };
  };

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.interfaces.eth0.useDHCP = true;

  zramSwap.enable = true;
}

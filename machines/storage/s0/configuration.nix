{ config, pkgs, lib, ... }:

{
  imports =[
    ./helios64
    ./hardware-configuration.nix
  ];

  # nsw2zwifzyl42mbhabayjo42b2kkq3wd3dqyl6efxsz6pvmgm5cup5ad.onion

  nix.flakes.enable = true;

  networking.hostName = "s0";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  system.autoUpgrade.enable = true;

  boot.supportedFilesystems = [ "bcachefs" ];

  # for education purposes only
  services.pykms.enable = true;
  services.pykms.openFirewallPort = true;

  users.users.googlebot.packages = with pkgs; [
    bcachefs-tools
  ];
}

{ config, pkgs, lib, ... }:

{
  imports =[
    ./helios64
    ./hardware-configuration.nix
  ];

  # nsw2zwifzyl42mbhabayjo42b2kkq3wd3dqyl6efxsz6pvmgm5cup5ad.onion

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

  services.samba.enable = true;

  services.plex = {
    enable = true;
    openFirewall = true;
    dataDir = "/data/plex";
  };
  users.users.${config.services.plex.user}.extraGroups = [ "public_data" ];
}

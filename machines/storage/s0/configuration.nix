{ config, pkgs, lib, ... }:

{
  imports =[
    ./helios64.nix
  ];

  nix.flakes.enable = true;
  networking.hostName = "s0";
  fileSystems."/" = { device = lib.mkForce "/dev/disk/by-label/bold-emmc"; fsType = lib.mkForce "btrfs"; };
  networking.interfaces.eth0.useDHCP = true;
}

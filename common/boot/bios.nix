{ config, pkgs, ... }:

{
  # Use GRUB 2 for BIOS
  boot.loader.grub = {
    enable = true;
    version = 2;
    useOSProber = true;
    configurationLimit = 20;
    theme = pkgs.nixos-grub2-theme;
  };
}
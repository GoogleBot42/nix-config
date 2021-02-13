{ config, pkgs, ... }:

{
  # Use GRUB2 for EFI

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      device = "nodev";
      version = 2;
      efiSupport = true;
      useOSProber = true;
#      memtest86.enable = true;
      configurationLimit = 20;
      theme = pkgs.nixos-grub2-theme;
    };
  };
}

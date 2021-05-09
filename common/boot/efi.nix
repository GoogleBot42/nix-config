{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.efi;
in {
  options.efi = {
    enable = mkEnableOption "enable efi boot";
  };

  config = mkIf cfg.enable {
    # Enable microcode
    firmware.x86_64 = true;
    # Use GRUB2 for EFI
    boot.loader = {
      efi.canTouchEfiVariables = true;
      timeout = 2;
      grub = {
        enable = true;
        device = "nodev";
        version = 2;
        efiSupport = true;
        useOSProber = true;
#       memtest86.enable = true;
        configurationLimit = 20;
        theme = pkgs.nixos-grub2-theme;
      };
    };
  };
}

{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.efi;
in
{
  options.efi = {
    enable = mkEnableOption "enable efi boot";
  };

  config = mkIf cfg.enable {
    boot.loader = {
      efi.canTouchEfiVariables = true;
      timeout = 2;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        #       memtest86.enable = true;
        configurationLimit = 20;
        theme = pkgs.nixos-grub2-theme;
      };
    };
  };
}

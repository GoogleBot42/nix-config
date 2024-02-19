{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.efi;
in
{
  options.efi = {
    enable = mkEnableOption "enable efi boot";
    configurationLimit = mkOption {
      default = 20;
      type = types.int;
    };
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
        configurationLimit = cfg.configurationLimit;
        theme = pkgs.nixos-grub2-theme;
      };
    };
  };
}

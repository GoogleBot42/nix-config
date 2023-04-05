{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.bios;
in
{
  options.bios = {
    enable = mkEnableOption "enable bios boot";
    device = mkOption {
      type = types.str;
    };
  };

  config = mkIf cfg.enable {
    # Use GRUB 2 for BIOS
    boot.loader = {
      timeout = 2;
      grub = {
        enable = true;
        device = cfg.device;
        version = 2;
        useOSProber = true;
        configurationLimit = 20;
        theme = pkgs.nixos-grub2-theme;
      };
    };
  };
}

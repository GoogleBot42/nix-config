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
    boot.loader = {
      timeout = 2;
      grub = {
        enable = true;
        device = cfg.device;
        useOSProber = true;
        configurationLimit = 20;
        theme = pkgs.nixos-grub2-theme;
      };
    };
  };
}

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
    configurationLimit = mkOption {
      default = 20;
      type = types.int;
    };
  };

  config = mkIf cfg.enable {
    boot.loader = {
      timeout = 2;
      grub = {
        enable = true;
        device = cfg.device;
        useOSProber = true;
        configurationLimit = cfg.configurationLimit;
        theme = pkgs.nixos-grub2-theme;
      };
    };
  };
}

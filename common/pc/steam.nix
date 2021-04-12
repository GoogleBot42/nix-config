{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in {
  config = lib.mkIf cfg.enable {
    programs.steam.enable = true;
    hardware.steam-hardware.enable = true; # steam controller

    users.users.googlebot.packages = [
      pkgs.steam
    ];
  };
}
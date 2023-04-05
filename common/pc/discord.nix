{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    users.users.googlebot.packages = [
      pkgs.discord
    ];
  };
}

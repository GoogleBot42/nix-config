{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    services.libinput.enable = true;
    services.libinput.touchpad.naturalScrolling = true;
  };
}

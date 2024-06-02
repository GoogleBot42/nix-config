{ lib, config, pkgs, ... }:

let
  cfg = config.de.touchpad;
in
{
  options.de.touchpad = {
    enable = lib.mkEnableOption "enable touchpad";
  };

  config = lib.mkIf cfg.enable {
    services.libinput.enable = true;
    services.libinput.touchpad.naturalScrolling = true;
  };
}

{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in {
  config = lib.mkIf cfg.enable {
    # Audio
    sound.enable = true;

    # enable pulseaudio support for packages
    nixpkgs.config.pulseaudio = true;

    # realtime pulseaudio
    security.rtkit.enable = true;

    hardware.pulseaudio = {
      enable = true;
      support32Bit = true;
      package = pkgs.pulseaudioFull; # bt headset support

      # TODO: switch on connect isn't working for some reason (at least when in kde)
      extraConfig = "
        load-module module-switch-on-connect
        load-module module-switch-on-connect ignore_virtual=no
      ";
    };
    users.users.googlebot.extraGroups = [ "audio" ];

    # bt headset support
    hardware.bluetooth.enable = true;
  };
}

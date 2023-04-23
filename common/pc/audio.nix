{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    # enable pulseaudio support for packages
    nixpkgs.config.pulseaudio = true;

    # realtime audio
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    users.users.googlebot.extraGroups = [ "audio" ];

    # bt headset support
    hardware.bluetooth.enable = true;
  };
}

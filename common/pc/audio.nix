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

    services.pipewire.extraConfig.pipewire."92-fix-wine-audio" = {
      context.properties = {
        default.clock.rate = 48000;
        default.clock.quantum = 2048;
        default.clock.min-quantum = 512;
        default.clock.max-quantum = 2048;
      };
    };

    users.users.googlebot.extraGroups = [ "audio" ];

    # bt headset support
    hardware.bluetooth.enable = true;
  };
}

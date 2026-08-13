{ lib, config, ... }:

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

    # note: keys must be quoted; PipeWire only understands flat dotted keys,
    # nested attrsets silently fail to apply
    services.pipewire.extraConfig.pipewire."92-fix-wine-audio" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 256;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 2048;
      };
    };

    # let the graph run at 96kHz when a hi-res device/stream asks for it
    services.pipewire.extraConfig.pipewire."93-hires-rates" = {
      "context.properties" = {
        "default.clock.allowed-rates" = [ 48000 96000 ];
      };
    };

    # Arctis Nova Pro Omni: always open the headset in its 96kHz/24-bit mode
    # (the mic only does 48kHz mono, so only the output node is matched)
    services.pipewire.wireplumber.extraConfig."51-arctis-nova-pro-hires" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~alsa_output.usb-.*Arctis_Nova_Pro_Omni.*"; }
          ];
          actions = {
            "update-props" = {
              "audio.rate" = 96000;
              "audio.format" = "S24LE";
            };
          };
        }
        # never suspend the mic: reopening the capture stream after idle
        # suspend can leave it with a stale, high-latency buffer and eats
        # the first moments of speech when apps grab the mic
        {
          matches = [
            { "node.name" = "~alsa_input.usb-.*Arctis_Nova_Pro_Omni.*"; }
          ];
          actions = {
            "update-props" = {
              "session.suspend-timeout-seconds" = 0;
            };
          };
        }
      ];
    };

    users.users.googlebot.extraGroups = [ "audio" ];

    # bt headset support
    hardware.bluetooth.enable = true;
  };
}

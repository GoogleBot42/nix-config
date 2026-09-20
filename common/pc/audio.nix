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

    # Arctis Nova Pro Omni. The card runs on the pro-audio profile, which turns
    # on IRQ-driven scheduling (api.alsa.disable-tsched) for every node. In that
    # mode PipeWire never corrects the capture buffer level: whatever offset the
    # USB stream starts with, plus anything a late IRQ leaves behind, stays for
    # the life of the node (spa/plugins/alsa/alsa-pcm.c, update_time). Timer
    # scheduling keeps the level at target, halves the period for batch (USB)
    # devices and adds headroom, so keep both nodes on it.
    services.pipewire.wireplumber.extraConfig."51-arctis-nova-pro-hires" = {
      "monitor.alsa.rules" = [
        # always open the headset output in its 96kHz/24-bit mode
        # (the mic only does 48kHz mono, so only the output node is matched)
        {
          matches = [
            { "node.name" = "~alsa_output.usb-.*Arctis_Nova_Pro_Omni.*"; }
          ];
          actions = {
            "update-props" = {
              "audio.rate" = 96000;
              "audio.format" = "S24LE";
              "api.alsa.disable-tsched" = false;
            };
          };
        }
        # never suspend the mic: reopening the capture stream after idle
        # suspend eats the first moments of speech when apps grab the mic
        {
          matches = [
            { "node.name" = "~alsa_input.usb-.*Arctis_Nova_Pro_Omni.*"; }
          ];
          actions = {
            "update-props" = {
              "session.suspend-timeout-seconds" = 0;
              "api.alsa.disable-tsched" = false;
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

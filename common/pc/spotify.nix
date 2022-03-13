{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.services.spotifyd;
  toml = pkgs.formats.toml {};
  spotifydConf = toml.generate "spotify.conf" cfg.settings;
in
{
  disabledModules = [
    "services/audio/spotifyd.nix"
  ];

  options = {
    services.spotifyd = {
      enable = mkEnableOption "spotifyd, a Spotify playing daemon";

      settings = mkOption {
        default = {};
        type = toml.type;
        example = { global.bitrate = 320; };
        description = ''
          Configuration for Spotifyd. For syntax and directives, see
          <link xlink:href="https://github.com/Spotifyd/spotifyd#Configuration"/>.
        '';
      };

      users = mkOption {
        type = with types; listOf str;
        default = [];
        description = ''
          Usernames to be added to the "spotifyd" group, so that they
          can start and interact with the userspace daemon.
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    # username specific stuff because i'm lazy...
    services.spotifyd.users = [ "googlebot" ];
    users.users.googlebot.packages = with pkgs; [
      spotify
      spotify-tui
    ];

    users.groups.spotifyd = {
      members = cfg.users;
    };

    age.secrets.spotifyd = {
      file = ../../secrets/spotifyd.age;
      group = "spotifyd";
    };

    # spotifyd to read secrets and run as user service
    services.spotifyd = {
      settings.global = {
        username_cmd = "sed '1q;d' /run/agenix/spotifyd";
        password_cmd = "sed '2q;d' /run/agenix/spotifyd";
        bitrate = 320;
        backend = "pulseaudio";
        device_name = config.networking.hostName;
        device_type = "computer";
        # on_song_change_hook = "command_to_run_on_playback_events"
        autoplay = true;
      };
    };

    systemd.user.services.spotifyd-daemon = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "sound.target" ];
      description = "spotifyd, a Spotify playing daemon";
      environment.SHELL = "/bin/sh";
      serviceConfig = {
        ExecStart = "${pkgs.spotifyd}/bin/spotifyd --no-daemon --config-path ${spotifydConf}";
        Restart = "always";
        CacheDirectory = "spotifyd";
      };
    };
  };
}
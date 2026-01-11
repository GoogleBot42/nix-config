{ config, lib, pkgs, ... }:

{
  services.esphome.enable = true;

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        users.root = {
          acl = [ "readwrite #" ];
          hashedPassword = "$7$101$8+QnkTzCdGizaKqq$lpU4o84n6D/1uwfA9pZDVExr1NDm1D/8tNla2tE9J9HdUqkvu192yYfiySY1MFqVNgUKgWEFu5P1bUKqRnzbUw==";
        };
      }
    ];
  };
  networking.firewall.allowedTCPPorts = [
    # mqtt
    1883

    # Must be exposed so some local devices (such as HA voice preview) can pair with home assistant
    config.services.home-assistant.config.http.server_port

    # Music assistant (must be exposed so local devices can fetch the audio stream from it)
    8095
    8097
  ];

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      permit_join = false;
      serial = {
        adapter = "ember";
        port = "/dev/ttyACM0";
      };
      mqtt = {
        server = "mqtt://localhost:1883";
        user = "root";
        password = "!/run/agenix/zigbee2mqtt.yaml mqtt_password";
      };
      frontend = {
        host = "localhost";
        port = 55834;
      };
    };
  };
  age.secrets."zigbee2mqtt.yaml" = {
    file = ../../../secrets/zigbee2mqtt.yaml.age;
    owner = "zigbee2mqtt";
  };

  services.home-assistant = {
    enable = true;
    extraComponents = [
      "default_config"
      "rest_command"
      "esphome"
      "met"
      "radio_browser"
      "wled"
      "mqtt"
      "apple_tv" # why is this even needed? I get `ModuleNotFoundError: No module named 'pyatv'` errors otherwise for some reason.
      "unifi"
      "digital_ocean"
      "downloader"
      "mailgun"
      "minecraft_server"
      "mullvad"
      "nextcloud"
      "ollama"
      "openweathermap"
      "jellyfin"
      "transmission"
      "radarr"
      "sonarr"
      "syncthing"
      "tailscale"
      "weather"
      "whois"
      "youtube"
      "homekit_controller"
      "zha"
      "bluetooth"
      "whisper"
      "piper"
      "wyoming"
      "tts"
      "music_assistant"
      "openai_conversation"
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = { };

      homeassistant = {
        external_url = "https://ha.s0.neet.dev";
        internal_url = "http://192.168.1.2:${toString config.services.home-assistant.config.http.server_port}";
      };

      # Enable reverse proxy support
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };

      "automation manual" = [
      ];
      # Allow using automations generated from the UI
      "automation ui" = "!include automations.yaml";

      "rest_command" = {
        json_post_request = {
          url = "{{ url }}";
          method = "POST";
          content_type = "application/json";
          payload = "{{ payload | default('{}') }}";
        };
      };
    };
  };

  services.wyoming.faster-whisper.servers."hass" = {
    enable = true;
    uri = "tcp://0.0.0.0:45785";
    model = "distil-small.en";
    language = "en";
  };

  services.wyoming.piper.servers."hass" = {
    enable = true;
    uri = "tcp://0.0.0.0:45786";
    voice = "en_US-joe-medium";
  };

  services.music-assistant = {
    enable = true;
    providers = [
      "hass"
      "hass_players"
      "jellyfin"
      "radiobrowser"
      "spotify"
    ];
  };
  networking.hosts = {
    # Workaround for broken spotify api integration
    # https://github.com/librespot-org/librespot/issues/1527#issuecomment-3167094158
    "0.0.0.0" = [ "apresolve.spotify.com" ];
  };
}

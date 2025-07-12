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
    1883 # mqtt
  ];

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant = true;
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
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = { };

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
}

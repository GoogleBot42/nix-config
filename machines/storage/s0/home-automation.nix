{ config, lib, pkgs, ... }:

{
  services.esphome.enable = true;

  # TODO lock down
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant = true;
      permit_join = false;
      serial = {
        port = "/dev/ttyACM0";
      };
      mqtt = {
        server = "mqtt://localhost:1883";
        # base_topic = "zigbee2mqtt";
      };
      frontend = {
        host = "localhost";
        port = 55834;
      };
    };
  };

  services.home-assistant = {
    enable = true;
    extraComponents = [
      "default_config"
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
    # config = null;
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
    };
  };
}

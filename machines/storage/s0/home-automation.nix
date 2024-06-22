{ config, lib, pkgs, ... }:

let
  frigateHostname = "frigate.s0.neet.dev";

  mkEsp32Cam = address: {
    ffmpeg = {
      input_args = "";
      inputs = [{
        path = address;
        roles = [ "detect" "record" ];
      }];

      output_args.record = "-f segment -pix_fmt yuv420p -segment_time 10 -segment_format mp4 -reset_timestamps 1 -strftime 1 -c:v libx264 -preset ultrafast -an ";
    };
    rtmp.enabled = false;
    snapshots = {
      enabled = true;
      bounding_box = true;
    };
    record = {
      enabled = true;
      retain.days = 10; # Keep video for 10 days
      events.retain = {
        default = 30; # Keep video with detections for 30 days
        mode = "active_objects";
      };
    };
    detect = {
      enabled = true;
      width = 800;
      height = 600;
      fps = 10;
    };
    objects = {
      track = [ "person" ];
    };
  };
in
{
  networking.firewall.allowedTCPPorts = [
    # 1883 # mqtt
  ];

  services.frigate = {
    enable = true;
    hostname = frigateHostname;
    settings = {
      mqtt = {
        enabled = true;
        host = "localhost:1883";
      };
      cameras = {
        dahlia-cam = mkEsp32Cam "http://dahlia-cam.lan:8080";
      };
      # ffmpeg = {
      #   hwaccel_args = "preset-vaapi";
      # };
      detectors.coral = {
        type = "edgetpu";
        device = "pci";
      };
    };
  };

  # AMD GPU for vaapi
  systemd.services.frigate.environment.LIBVA_DRIVER_NAME = "radeonsi";

  # Coral TPU for frigate
  services.udev.packages = [ pkgs.libedgetpu ];
  users.groups.apex = { };
  systemd.services.frigate.environment.LD_LIBRARY_PATH = "${pkgs.libedgetpu}/lib";
  systemd.services.frigate.serviceConfig = {
    SupplementaryGroups = "apex";
  };
  # Coral PCIe driver
  kernel.enableGasketKernelModule = true;

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

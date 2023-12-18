{ config, lib, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [
    # 1883 # mqtt
    55834 # mqtt zigbee frontend
  ];

  services.frigate = {
    enable = true;
    hostname = "frigate.s0";
    settings = {
      mqtt = {
        enabled = true;
        host = "localhost:1883";
      };
      cameras = {
        dahlia-cam = {
          ffmpeg = {
            input_args = "";
            inputs = [{
              path = "http://dahlia-cam.lan:8080";
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
            enabled = false;
            retain.days = 0; # To not retain any recording if there is no detection of any events 
            events.retain = {
              default = 3; # To retain recording for 3 days of only the events that happened
              mode = "active_objects";
            };
          };
          detect = {
            enabled = true;
            width = 800;
            height = 600;
            fps = 20;
          };
          objects = {
            track = [ "dog" ];
            filters.dog.threshold = 0.4;
          };
        };
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

  services.esphome = {
    enable = true;
    address = "0.0.0.0";
    openFirewall = true;
  };
  # TODO remove after upgrading nixos version
  systemd.services.esphome.serviceConfig.ProcSubset = lib.mkForce "all";
  systemd.services.esphome.serviceConfig.ProtectHostname = lib.mkForce false;
  systemd.services.esphome.serviceConfig.ProtectKernelLogs = lib.mkForce false;
  systemd.services.esphome.serviceConfig.ProtectKernelTunables = lib.mkForce false;

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
        host = "0.0.0.0";
        port = 55834;
      };
    };
  };

  services.home-assistant = {
    enable = true;
    openFirewall = true;
    configWritable = true;
    extraComponents = [
      "esphome"
      "met"
      "radio_browser"
      "wled"
      "mqtt"
    ];
    # config = null;
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = { };
    };
  };
}

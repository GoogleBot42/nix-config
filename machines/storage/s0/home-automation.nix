{ config, lib, pkgs, ... }:

let
  frigateHostname = "frigate.s0";
  frigatePort = 61617;

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
    55834 # mqtt zigbee frontend
    frigatePort
    4180 # oauth proxy
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

  # Allow accessing frigate UI on a specific port in addition to by hostname
  services.nginx.virtualHosts.${frigateHostname} = {
    listen = [{ addr = "0.0.0.0"; port = frigatePort; } { addr = "0.0.0.0"; port = 80; }];
  };

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

  services.oauth2_proxy =
    let
      nextcloudServer = "https://neet.cloud/";
    in
    {
      enable = true;

      httpAddress = "http://0.0.0.0:4180";

      nginx.virtualHosts = [
        frigateHostname
      ];

      email.domains = [ "*" ];

      cookie.secure = false;

      provider = "nextcloud";

      # redirectURL = "http://s0:4180/oauth2/callback"; # todo forward with nginx?
      clientID = "4FfhEB2DNzUh6wWhXTjqQQKu3Ibm6TeYpS8TqcHe55PJC1DorE7vBZBELMKDjJ0X";
      keyFile = "/run/agenix/oauth2-proxy-env";

      loginURL = "${nextcloudServer}/index.php/apps/oauth2/authorize";
      redeemURL = "${nextcloudServer}/index.php/apps/oauth2/api/v1/token";
      validateURL = "${nextcloudServer}/ocs/v2.php/cloud/user?format=json";

      # todo --cookie-refresh

      extraConfig = {
        # cookie-csrf-per-request = true;
        # cookie-csrf-expire = "5m";
        # user-id-claim = "preferred_username";
      };
    };

  age.secrets.oauth2-proxy-env.file = ../../../secrets/oauth2-proxy-env.age;
}

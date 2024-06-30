{ config, pkgs, lib, ... }:

let
  frigateHostname = "frigate.s0.neet.dev";

  mkEsp32Cam = address: {
    ffmpeg = {
      input_args = "";
      inputs = [{
        path = "http://${address}:8080";
        roles = [ "detect" "record" ];
      }];

      output_args.record = "-f segment -pix_fmt yuv420p -segment_time 10 -segment_format mp4 -reset_timestamps 1 -strftime 1 -c:v libx264 -preset ultrafast -an ";
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

  mkDahuaCam = address: {
    ffmpeg = {
      inputs = [
        {
          path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@${address}/cam/realmonitor?channel=1&subtype=0";
          roles = [ "record" ];
        }
        {
          path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@${address}/cam/realmonitor?channel=1&subtype=1";
          roles = [ "detect" ];
        }
      ];
    };
    detect.enabled = true;
    objects = {
      track = [ "person" "dog" ];
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
      rtmp.enabled = false;
      snapshots = {
        enabled = true;
        bounding_box = true;
      };
      record = {
        enabled = true;
        # sync_recordings = true; # detect if recordings were deleted outside of frigate
        retain = {
          days = 2; # Keep video for 2 days
          mode = "motion";
        };
        events = {
          retain = {
            default = 10; # Keep video with detections for 10 days
            mode = "motion";
            # mode = "active_objects";
          };
        };
      };
      cameras = {
        dahlia-cam = mkEsp32Cam "dahlia-cam.lan";
        dog-cam = mkDahuaCam "192.168.10.31";
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

  # Pass in env file with secrets to frigate
  systemd.services.frigate.serviceConfig.EnvironmentFile = "/run/agenix/frigate-credentials";
  age.secrets.frigate-credentials.file = ../../../secrets/frigate-credentials.age;

  # AMD GPU for vaapi
  systemd.services.frigate.environment.LIBVA_DRIVER_NAME = "radeonsi";

  # Coral TPU for frigate
  services.udev.packages = [ pkgs.libedgetpu ];
  users.groups.apex = { };
  systemd.services.frigate.environment.LD_LIBRARY_PATH = "${pkgs.libedgetpu}/lib";
  systemd.services.frigate.serviceConfig.SupplementaryGroups = "apex";
  # Coral PCIe driver
  kernel.enableGasketKernelModule = true;
}

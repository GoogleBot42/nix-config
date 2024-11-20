{ config, pkgs, lib, ... }:

let
  frigateHostname = "frigate.s0.neet.dev";

  mkGo2RtcStream = name: url: withAudio: {
    ${name} = [
      url
      "ffmpeg:${name}#video=copy${if withAudio then "#audio=copy" else ""}"
    ];
  };

  # Assumes camera is set to output:
  # - rtsp
  # - H.264 + AAC
  # - a downscaled substream for detection
  mkCamera = name: primaryUrl: detectUrl: {
    # Reference https://docs.frigate.video/configuration/reference/
    services.frigate.settings = {
      cameras.${name} = {
        ffmpeg = {
          # Camera feeds are relayed through go2rtc
          inputs = [
            {
              path = "rtsp://127.0.0.1:8554/${name}";
              # input_args = "preset-rtsp-restream";
              input_args = "preset-rtsp-restream-low-latency";
              roles = [ "record" ];
            }
            {
              path = detectUrl;
              roles = [ "detect" ];
            }
          ];
          output_args = {
            record = "preset-record-generic-audio-copy";
          };
        };
      };
    };
    services.go2rtc.settings.streams = lib.mkMerge [
      (mkGo2RtcStream name primaryUrl false)

      # Sadly having the detection stream go through go2rpc too makes the stream unreadable by frigate for some reason.
      # It might need to be re-encoded to work.  But I am not interested in wasting the processing power if only frigate
      # need the detection stream anyway. So just let frigate grab the stream directly since it works.
      # (mkGo2RtcStream detectName detectUrl false)
    ];
  };

  mkDahuaCamera = name: address:
    let
      # go2rtc and frigate have a slightly different syntax for inserting env vars. So the URLs are not interchangable :(
      # - go2rtc: ${VAR}
      # - frigate: {VAR}
      primaryUrl = "rtsp://admin:\${FRIGATE_RTSP_PASSWORD}@${address}/cam/realmonitor?channel=1&subtype=0";
      detectUrl = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@${address}/cam/realmonitor?channel=1&subtype=1";
    in
    mkCamera name primaryUrl detectUrl;

  mkEsp32Camera = name: address: {
    services.frigate.settings.cameras.${name} = {
      ffmpeg = {
        input_args = "";
        inputs = [{
          path = "http://${address}:8080";
          roles = [ "detect" "record" ];
        }];

        output_args.record = "-f segment -pix_fmt yuv420p -segment_time 10 -segment_format mp4 -reset_timestamps 1 -strftime 1 -c:v libx264 -preset ultrafast -an ";
      };
    };
  };
in
lib.mkMerge [
  (mkDahuaCamera "dog-cam" "192.168.10.31")
  # (mkEsp32Camera "dahlia-cam" "dahlia-cam.lan")
  {
    services.frigate = {
      enable = true;
      hostname = frigateHostname;
      settings = {
        mqtt = {
          enabled = true;
          host = "localhost";
          port = 1883;
          user = "root";
          password = "{FRIGATE_MQTT_PASSWORD}";
        };
        snapshots = {
          enabled = true;
          bounding_box = true;
        };
        record = {
          enabled = true;
          # sync_recordings = true; # detect if recordings were deleted outside of frigate (expensive)
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
        # Make frigate aware of the go2rtc streams
        go2rtc.streams = config.services.go2rtc.settings.streams;
        detect.enabled = true;
        objects = {
          track = [ "person" "dog" ];
        };
      };
    };

    services.go2rtc = {
      enable = true;
      settings = {
        rtsp.listen = ":8554";
        webrtc.listen = ":8555";
      };
    };

    # Pass in env file with secrets to frigate/go2rtc
    systemd.services.frigate.serviceConfig.EnvironmentFile = "/run/agenix/frigate-credentials";
    systemd.services.go2rtc.serviceConfig.EnvironmentFile = "/run/agenix/frigate-credentials";
    age.secrets.frigate-credentials.file = ../../../secrets/frigate-credentials.age;
  }
  {
    # hardware encode/decode with amdgpu vaapi
    systemd.services.frigate = {
      environment.LIBVA_DRIVER_NAME = "radeonsi";
      serviceConfig = {
        SupplementaryGroups = [ "render" "video" ]; # for access to dev/dri/*
        AmbientCapabilities = "CAP_PERFMON";
      };
    };
    services.frigate.settings.ffmpeg.hwaccel_args = "preset-vaapi";
  }
  {
    # Coral TPU for frigate
    services.udev.packages = [ pkgs.libedgetpu ];
    users.groups.apex = { };
    systemd.services.frigate.environment.LD_LIBRARY_PATH = "${pkgs.libedgetpu}/lib";
    systemd.services.frigate.serviceConfig.SupplementaryGroups = [ "apex" ];

    # Coral PCIe driver
    boot.extraModulePackages = with config.boot.kernelPackages; [ gasket ];
    services.udev.extraRules = ''
      SUBSYSTEM=="apex", MODE="0660", GROUP="apex"
    '';

    services.frigate.settings.detectors.coral = {
      type = "edgetpu";
      device = "pci";
    };
  }
  {
    # Fix bug in nixos module where cache is not cleared when starting the service because "rm" cannot be found
    systemd.services.frigate.serviceConfig.ExecStartPre = lib.mkForce "${pkgs.bash}/bin/sh -c 'rm -f /var/cache/frigate/*.mp4'";
  }
  {
    # Don't require authentication for frigate
    # This is ok because the reverse proxy already requires tailscale access anyway
    services.frigate.settings.auth.enabled = false;
  }
]

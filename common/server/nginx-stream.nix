{ lib, config, ... }:

let
  cfg = config.services.nginx.stream;
  nginxWithRTMP = pkgs.nginx.override {
    modules = [ pkgs.nginxModules.rtmp ];
  };
in {
  options.services.nginx.stream = {
    enable = lib.mkEnableOption "enable nginx rtmp/hls/dash video streaming";
    port = lib.mkOption {
      type = lib.types.int;
      default = 1935;
      description = "rtmp injest/serve port";
    };
    rtmpName = lib.mkOption {
      type = lib.types.string;
      default = "live";
      description = "the name of the rtmp application";
    };
    hostname = lib.mkOption {
      type = lib.types.string;
      description = "the http host to serve hls";
    };
    httpLocation = lib.mkOption {
      type = lib.types.string;
      default = "/tmp/stream";
      description = "the path of the tmp http files";
    };
  };
  config = lib.mkIf cfg.enable {
    services.nginx = {
      services.nginx.enable = true;

      package = nginxWithRTMP;

      virtualHosts.${cfg.hostname} = {
        enableACME = true;
        forceSSL = true;
        locations."/stream".root = cfg.httpLocation;
        extraConfig = ''
          location /stat {
            rtmp_stat all;
          }
        '';
      };

      appendConfig = ''
        rtmp {
          server {
            listen 1935;
            chunk_size 4096;
            application ${cfg.rtmpName} {
              allow publish 127.0.0.1;
              deny publish all;
              allow publish all;
              live on;
              record off;
              hls on;
              hls_path ${cfg.httpLocation}/hls;
              dash on;
              dash_path ${cfg.httpLocation}/dash;
            }
          }
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [
      cfg.stream.port
    ];
  };
}
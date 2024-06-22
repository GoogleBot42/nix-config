{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.dashy;
in
{
  options.services.dashy = {
    enable = mkEnableOption "dashy";
    imageTag = mkOption {
      type = types.str;
      default = "latest";
    };
    port = mkOption {
      type = types.int;
      default = 56815;
    };
    configFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the YAML configuration file";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      dashy = {
        image = "lissy93/dashy:${cfg.imageTag}";
        environment = {
          TZ = "${config.time.timeZone}";
        };
        ports = [
          "127.0.0.1:${toString cfg.port}:80"
        ];
        volumes = [
          "${cfg.configFile}:/app/public/conf.yml"
        ];
      };
    };
  };
}

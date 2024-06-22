{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.librechat;
in
{
  options.services.librechat = {
    enable = mkEnableOption "librechat";
    port = mkOption {
      type = types.int;
      default = 3080;
    };
    host = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers = {
      librechat = {
        image = "ghcr.io/danny-avila/librechat:v0.6.6";
        environment = {
          HOST = "0.0.0.0";
          MONGO_URI = "mongodb://host.containers.internal:27017/LibreChat";
          ENDPOINTS = "openAI,google,bingAI,gptPlugins";
          REFRESH_TOKEN_EXPIRY = toString (1000 * 60 * 60 * 24 * 30); # 30 days
        };
        environmentFiles = [
          "/run/agenix/librechat-env-file"
        ];
        ports = [
          "${toString cfg.port}:3080"
        ];
      };
    };
    age.secrets.librechat-env-file.file = ../../secrets/librechat-env-file.age;

    services.mongodb.enable = true;
    services.mongodb.bind_ip = "0.0.0.0";

    # easier podman maintenance
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.dockerSocket.enable = true;
    virtualisation.podman.dockerCompat = true;

    # For mongodb access
    networking.firewall.trustedInterfaces = [
      "podman0" # for librechat
    ];

    services.nginx.virtualHosts.${cfg.host} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString cfg.port}";
        proxyWebsockets = true;
      };
    };
  };
}

{ lib, config, ... }:

let
  cfg = config.services.uptime-kuma;
  port = 3001;
in
{
  options.services.uptime-kuma = {
    hostname = lib.mkOption {
      type = lib.types.str;
      example = "status.example.com";
    };
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma.settings = {
      HOST = "127.0.0.1";
      PORT = toString port;
    };

    # backups
    backup.group."uptime-kuma".paths = [
      "/var/lib/uptime-kuma"
    ];

    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.hostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
      };
    };
  };
}

{ lib, config, ... }:

let
  cfg = config.services.gatus;
  port = 31103;
in
{
  options.services.gatus = {
    hostname = lib.mkOption {
      type = lib.types.str;
      example = "status.example.com";
    };
  };

  config = lib.mkIf cfg.enable {
    services.gatus = {
      environmentFile = "/run/agenix/ntfy-token";
      settings = {
        storage = {
          type = "sqlite";
          path = "/var/lib/gatus/data.db";
        };

        web = {
          address = "127.0.0.1";
          port = port;
        };

        alerting.ntfy = {
          url = "https://ntfy.neet.dev";
          topic = "service-failures";
          priority = 4;
          default-alert = {
            enabled = true;
            failure-threshold = 3;
            success-threshold = 2;
            send-on-resolved = true;
          };
          token = "$NTFY_TOKEN";
        };

        endpoints = [
          {
            name = "Gitea";
            group = "services";
            url = "https://git.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "The Lounge";
            group = "services";
            url = "https://irc.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "ntfy";
            group = "services";
            url = "https://ntfy.neet.dev/v1/health";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Librechat";
            group = "services";
            url = "https://chat.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Owncast";
            group = "services";
            url = "https://live.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Nextcloud";
            group = "services";
            url = "https://neet.cloud";
            interval = "5m";
            conditions = [
              "[STATUS] == any(200, 302)"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Element Web";
            group = "services";
            url = "https://chat.neet.space";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Mumble";
            group = "services";
            url = "tcp://voice.neet.space:23563";
            interval = "5m";
            conditions = [
              "[CONNECTED] == true"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Navidrome";
            group = "services";
            url = "https://navidrome.neet.cloud";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
        ];
      };
    };
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

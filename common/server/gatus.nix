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
            name = "Roundcube";
            group = "services";
            url = "https://mail.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Collabora Online";
            group = "services";
            url = "https://collabora.runyan.org";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Jellyfin";
            group = "s0";
            url = "https://jellyfin.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Sonarr";
            group = "s0";
            url = "https://sonarr.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Radarr";
            group = "s0";
            url = "https://radarr.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Lidarr";
            group = "s0";
            url = "https://lidarr.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Prowlarr";
            group = "s0";
            url = "https://prowlarr.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Bazarr";
            group = "s0";
            url = "https://bazarr.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Transmission";
            group = "s0";
            url = "https://transmission.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Home Assistant";
            group = "s0";
            url = "https://ha.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "ESPHome";
            group = "s0";
            url = "https://esphome.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Zigbee2MQTT";
            group = "s0";
            url = "https://zigbee.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Frigate";
            group = "s0";
            url = "https://frigate.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Valetudo";
            group = "s0";
            url = "https://vacuum.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Sandman";
            group = "s0";
            url = "https://sandman.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Vikunja";
            group = "s0";
            url = "https://todo.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Actual Budget";
            group = "s0";
            url = "https://budget.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Linkwarden";
            group = "s0";
            url = "https://linkwarden.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Memos";
            group = "s0";
            url = "https://memos.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Outline";
            group = "s0";
            url = "https://outline.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "LanguageTool";
            group = "s0";
            url = "https://languagetool.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Unifi";
            group = "s0";
            url = "https://unifi.s0.neet.dev";
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

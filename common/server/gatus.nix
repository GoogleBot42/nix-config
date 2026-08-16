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
            name = "Gitea";
            group = "kif";
            url = "https://git.neet.dev/api/healthz";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Matrix";
            group = "kif";
            url = "https://neet.space/health";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Element";
            group = "kif";
            url = "https://chat.neet.space";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Nextcloud";
            group = "kif";
            url = "https://runyan.org/status.php";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Roundcube";
            group = "kif";
            url = "https://mail.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "SMTP";
            group = "kif";
            url = "tcp://mail.neet.dev:465";
            interval = "5m";
            conditions = [
              "[CONNECTED] == true"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "IMAP";
            group = "kif";
            url = "tcp://mail.neet.dev:993";
            interval = "5m";
            conditions = [
              "[CONNECTED] == true"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "TheLounge";
            group = "kif";
            url = "https://irc.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "pgs";
            group = "kif";
            url = "https://sites.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Hermes Dashboard";
            group = "fry";
            url = "https://hermes.fry.neet.dev/api/status";
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
            name = "Music Assistant";
            group = "s0";
            url = "http://s0.koi-bebop.ts.net:8095";
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
            name = "Unifi";
            group = "s0";
            url = "https://unifi.s0.neet.dev";
            interval = "5m";
            conditions = [
              "[STATUS] == 200"
            ];
            alerts = [{ type = "ntfy"; }];
          }
          {
            name = "Hermes Memories";
            group = "fry";
            url = "https://hermes-memories.fry.neet.dev/api/health";
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
      enableACME = lib.mkDefault true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
      };
    };
  };
}

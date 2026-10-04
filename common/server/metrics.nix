{ lib, config, pkgs, ... }:

# Fleet metrics: VictoriaMetrics (storage + scraper) and Grafana (dashboards,
# alerting, image rendering) on one host. Both bind to loopback and are reached
# only through their nginx virtual hosts, which the machine config pins to the
# tailnet address.

let
  vmCfg = config.services.victoriametrics;
  grafanaCfg = config.services.grafana;
  vmPort = 8428;
  grafanaPort = 3000;
  tailnet = config.services.tailscale.tailnetDomain;
  hostName = config.networking.hostName;

  # Node Exporter Full (grafana.com dashboard 1860), pinned by revision.
  nodeExporterFullDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/1860/revisions/45/download";
    hash = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
  };
  fleetDashboards = pkgs.runCommand "grafana-fleet-dashboards" { } ''
    mkdir -p $out
    cp ${nodeExporterFullDashboard} $out/node-exporter-full.json
  '';
in
{
  options.services.victoriametrics.hostname = lib.mkOption {
    type = lib.types.str;
    example = "metrics.example.com";
    description = "Virtual host fronting the VictoriaMetrics HTTP API (import, query, vmui).";
  };

  options.services.grafana = {
    hostname = lib.mkOption {
      type = lib.types.str;
      example = "grafana.example.com";
    };
    ntfyTopic = lib.mkOption {
      type = lib.types.str;
      default = "grafana";
      description = "ntfy topic the provisioned alerting contact point publishes to.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf vmCfg.enable {
      services.victoriametrics = {
        listenAddress = "127.0.0.1:${toString vmPort}";
        retentionPeriod = "5y";
        extraOptions = [ "-selfScrapeInterval=30s" ];
        prometheusConfig = {
          global.scrape_interval = "30s";
          scrape_configs = [
            {
              job_name = "node";
              static_configs = map
                (host: {
                  targets = [ "${host}.${tailnet}:${toString config.services.prometheus.exporters.node.port}" ];
                  labels.instance = host;
                })
                (lib.attrNames config.machines.hosts);
            }
          ] ++ lib.optional config.services.pgs.enable {
            job_name = "pgs";
            static_configs = [{
              targets = [ "127.0.0.1:${toString config.services.pgs.prometheusPort}" ];
              labels.instance = hostName;
            }];
          };
        };
      };

      backup.group."victoriametrics".paths = [ "/var/lib/${vmCfg.stateDir}" ];

      services.nginx.enable = true;
      services.nginx.virtualHosts.${vmCfg.hostname} = {
        enableACME = lib.mkDefault true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString vmPort}";
          extraConfig = ''
            client_max_body_size 64m;
          '';
        };
      };
    })

    (lib.mkIf grafanaCfg.enable {
      services.grafana = {
        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = grafanaPort;
            domain = grafanaCfg.hostname;
            root_url = "https://${grafanaCfg.hostname}/";
          };
          # Both secrets are generated on the host at first start (see preStart)
          # and live in the backed-up data dir. admin_password is only read when
          # the database is first created.
          security = {
            secret_key = "$__file{${grafanaCfg.dataDir}/secret_key}";
            admin_user = "admin";
            admin_password = "$__file{${grafanaCfg.dataDir}/admin_password}";
          };
          users.allow_sign_up = false;
          analytics = {
            reporting_enabled = false;
            check_for_updates = false;
            check_for_plugin_updates = false;
            feedback_links_enabled = false;
          };
        };

        provision = {
          enable = true;
          datasources.settings.datasources = [{
            name = "VictoriaMetrics";
            type = "prometheus";
            uid = "victoriametrics";
            url = "http://127.0.0.1:${toString vmPort}";
            isDefault = true;
          }];
          dashboards.settings.providers = [{
            name = "fleet";
            folder = "Fleet";
            options.path = fleetDashboards;
          }];
          alerting = {
            contactPoints.settings = {
              apiVersion = 1;
              contactPoints = [{
                orgId = 1;
                name = "ntfy";
                receivers = [{
                  uid = "ntfy";
                  type = "webhook";
                  settings = {
                    url = "${config.ntfy-alerts.serverUrl}/${grafanaCfg.ntfyTopic}?template=grafana";
                    httpMethod = "POST";
                    authorization_scheme = "Bearer";
                    authorization_credentials = "$NTFY_TOKEN";
                  };
                }];
              }];
            };
            policies.settings = {
              apiVersion = 1;
              policies = [{
                orgId = 1;
                receiver = "ntfy";
              }];
            };
          };
        };
      };

      systemd.services.grafana = {
        preStart = lib.mkBefore ''
          for f in secret_key admin_password; do
            if [ ! -s "${grafanaCfg.dataDir}/$f" ]; then
              (umask 077; ${pkgs.openssl}/bin/openssl rand -hex 32 > "${grafanaCfg.dataDir}/$f")
            fi
          done
        '';
        # The contact point's bearer token comes from the same agenix env file
        # Gatus uses (NTFY_TOKEN=...).
        serviceConfig.EnvironmentFile = [ "/run/agenix/ntfy-token" ];
      };

      # Lets API clients fetch any panel as a PNG.
      services.grafana-image-renderer = {
        enable = true;
        provisionGrafana = true;
      };

      backup.group."grafana".paths = [ grafanaCfg.dataDir ];

      services.nginx.enable = true;
      services.nginx.virtualHosts.${grafanaCfg.hostname} = {
        enableACME = lib.mkDefault true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString grafanaPort}";
          proxyWebsockets = true;
        };
      };
    })
  ];
}

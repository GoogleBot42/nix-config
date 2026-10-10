{ lib, config, pkgs, ... }:

# Fleet metrics: VictoriaMetrics (storage + scraper) and Grafana (dashboards,
# alerting, image rendering) on one host. Both bind to loopback and are reached
# only through their nginx virtual hosts, which the machine config pins to the
# tailnet address.

let
  vmCfg = config.services.victoriametrics;
  grafanaCfg = config.services.grafana;
  vmPort = 8428;
  # Not 3000: Gitea owns that on kif.
  grafanaPort = 3031;
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
    cp ${./dashboards/hardware-sensors.json} $out/hardware-sensors.json
  '';

  diskCfg = grafanaCfg.diskAlerts;

  # Filesystem usage in percent, per host and mountpoint, filtered to the
  # series above `threshold`; `hosts` (null = every host) narrows it by instance.
  mkDiskRule = { uid, severity, threshold, hosts }:
    let
      # /nix/store is a bind mount of / on every host, so it would alert twice.
      usage = ''100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs", mountpoint!="/nix/store"} / node_filesystem_size_bytes)'';
      hostFilter = lib.optionalString (hosts != null)
        " and on(instance) up{job=\"node\", instance=~\"${lib.concatStringsSep "|" hosts}\"}";
    in
    {
      inherit uid;
      title = "Filesystem above ${toString threshold}%${lib.optionalString (hosts != null) " (${lib.concatStringsSep ", " hosts})"}";
      condition = "C";
      data = [
        {
          refId = "A";
          relativeTimeRange = { from = 300; to = 0; };
          datasourceUid = "victoriametrics";
          model = {
            refId = "A";
            instant = true;
            expr = "(${usage} > ${toString threshold})${hostFilter}";
          };
        }
        {
          refId = "C";
          datasourceUid = "__expr__";
          model = {
            refId = "C";
            type = "threshold";
            expression = "A";
            conditions = [{ evaluator = { type = "gt"; params = [ 0 ]; }; }];
          };
        }
      ];
      for = "10m";
      noDataState = "OK";
      execErrState = "Error";
      labels = { inherit severity; };
      annotations.summary = ''{{ $labels.instance }}:{{ $labels.mountpoint }} is {{ printf "%.0f" $values.A.Value }}% full'';
    };
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
    diskAlerts = {
      critical = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 90;
        description = "Filesystem usage percentage at which every host raises a critical alert.";
      };
      warning = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 50;
        description = "Filesystem usage percentage at which the hosts in warningHosts raise an early warning.";
      };
      warningHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "kif" "s0" ];
        description = "Hosts (instance labels) that also get the early-warning alert.";
      };
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
              targets = [ "${config.services.pgs.sshHost}:${toString config.services.pgs.prometheusPort}" ];
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
          # admin_password is only read when the database is first created.
          security = {
            secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
            admin_user = "admin";
            admin_password = "$__file{${config.age.secrets.grafana-admin-password.path}}";
          };
          users.allow_sign_up = false;
          rendering.renderer_token = "$__env{AUTH_TOKEN}";
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
            rules.settings = {
              apiVersion = 1;
              groups = [{
                orgId = 1;
                name = "fleet";
                folder = "Fleet";
                interval = "1m";
                rules = [
                  (mkDiskRule {
                    uid = "fleet-disk-critical";
                    severity = "critical";
                    threshold = diskCfg.critical;
                    hosts = null;
                  })
                ] ++ lib.optional (diskCfg.warningHosts != [ ]) (mkDiskRule {
                  uid = "fleet-disk-warning";
                  severity = "warning";
                  threshold = diskCfg.warning;
                  hosts = diskCfg.warningHosts;
                });
              }];
            };
          };
        };
      };

      age.secrets = {
        grafana-admin-password = {
          file = ../../secrets/grafana-admin-password.age;
          owner = "grafana";
        };
        grafana-secret-key = {
          file = ../../secrets/grafana-secret-key.age;
          owner = "grafana";
        };
        # AUTH_TOKEN=... shared by Grafana and the image renderer; read by systemd.
        grafana-renderer-env.file = ../../secrets/grafana-renderer-env.age;
      };

      # NTFY_TOKEN for the contact point comes from the same agenix env file
      # Gatus uses.
      systemd.services.grafana.serviceConfig.EnvironmentFile = [
        "/run/agenix/ntfy-token"
        config.age.secrets.grafana-renderer-env.path
      ];
      systemd.services.grafana-image-renderer.serviceConfig.EnvironmentFile = [
        config.age.secrets.grafana-renderer-env.path
      ];

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

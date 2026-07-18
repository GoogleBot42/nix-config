{ config, lib, pkgs, ... }:

let
  cfg = config.services.pgs;
  env = {
    DATABASE_URL = "${cfg.dataDir}/pgs.sqlite3";
    FS_STORAGE_DIR = "${cfg.dataDir}/storage";
    PGS_CACHE_TTL = cfg.cacheTtl;
    PGS_DOMAIN = cfg.domain;
    PGS_HOST = cfg.sshHost;
    PGS_PROTOCOL = "https";
    PGS_PROM_PORT = toString cfg.prometheusPort;
    PGS_SSH_HOST = cfg.sshHost;
    PGS_SSH_PORT = toString cfg.sshPort;
    PGS_WEB_PORT = toString cfg.webPort;
    STORAGE_ADAPTER = "fs";
    USE_IMGPROXY = "0";
  };

  initialUserArgs = lib.concatMapStringsSep " "
    (user: lib.concatMapStringsSep " "
      (key: "${lib.escapeShellArg user} ${lib.escapeShellArg key}")
      cfg.initialUsers.${user})
    (lib.attrNames cfg.initialUsers);
  initUserUnit = lib.optional (cfg.initialUsers != { }) "pgs-init-users.service";
in
{
  options.services.pgs = {
    enable = lib.mkEnableOption "pgs static site hosting";

    package = lib.mkPackageOption pkgs "pgs" { };

    domain = lib.mkOption {
      type = lib.types.str;
      example = "sites.example.com";
      description = "Base pgs domain. Projects are served as subdomains of this domain.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/pgs";
      description = "Directory for the pgs SQLite database, uploaded site storage, and SSH host key.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "pgs";
      description = "Dedicated Unix user that runs pgs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "pgs";
      description = "Dedicated Unix group that runs pgs.";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 3005;
      description = "Local HTTP port for the pgs web service.";
    };

    sshHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address for the pgs SSH server to bind.";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "Port for the pgs SSH upload service.";
    };

    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 9225;
      description = "Prometheus metrics port for the pgs SSH server.";
    };

    cacheTtl = lib.mkOption {
      type = lib.types.str;
      default = "600s";
      description = "pgs HTTP cache TTL, parsed by Go time.ParseDuration.";
    };

    initialUsers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = lib.literalExpression ''{ jeremy = [ "ssh-ed25519 AAAA..." ]; }'';
      description = "Initial pgs users and public keys to register on service start. Existing keys are ignored.";
    };

    nginx = {
      enable = lib.mkEnableOption "nginx reverse proxy for pgs";

      tailscaleOnly = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Bind pgs nginx virtual hosts only to services.nginx.tailscaleListenAddress.";
      };

      useACMEHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = cfg.domain;
        defaultText = lib.literalExpression "config.services.pgs.domain";
        description = "Wildcard ACME certificate name to reuse for pgs nginx virtual hosts.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
      createHome = true;
      shell = "${pkgs.shadow}/bin/nologin";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/storage 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.pgs = {
      description = "pgs static site hosting";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ] ++ initUserUnit;
      wants = [ "network-online.target" ] ++ initUserUnit;
      environment = env;
      path = [ cfg.package ];
      preStart = ''
        set -euo pipefail
        mkdir -p ${cfg.dataDir}/ssh_data ${cfg.dataDir}/storage ${cfg.dataDir}/pkg/apps
        ln -sfn ${cfg.package}/share/pgs/pkg/apps/pgs ${cfg.dataDir}/pkg/apps/pgs
        chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
      '';
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package}";
        Restart = "on-failure";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
      };
    };

    systemd.services.pgs-init-users = lib.mkIf (cfg.initialUsers != { }) {
      description = "Initialize pgs users";
      before = [ "pgs.service" ];
      environment = env;
      path = [ cfg.package ];
      script = ''
        set -euo pipefail
        mkdir -p ${cfg.dataDir}/ssh_data ${cfg.dataDir}/storage
        chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
        set -- '' + initialUserArgs + ''

        while [ "$#" -gt 0 ]; do
          user="$1"
          key="$2"
          shift 2
          ${lib.getExe cfg.package} init "$user" "$key" || true
        done
      '';
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
      };
    };

    services.nginx = lib.mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts = {
        ${cfg.domain} = {
          tailscaleOnly = cfg.nginx.tailscaleOnly;
          useACMEHost = cfg.nginx.useACMEHost;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:${toString cfg.webPort}";
        };
        "*.${cfg.domain}" = {
          tailscaleOnly = cfg.nginx.tailscaleOnly;
          useACMEHost = cfg.nginx.useACMEHost;
          forceSSL = true;
          locations."/".proxyPass = "http://127.0.0.1:${toString cfg.webPort}";
        };
      };
    };
  };
}

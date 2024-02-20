# Starting point:
# https://github.com/aldoborrero/mynixpkgs/commit/c501c1e32dba8f4462dcecb57eee4b9e52038e27

{ config, pkgs, lib, ... }:

let
  cfg = config.services.actual-server;
  stateDir = "/var/lib/${cfg.stateDirName}";
in
{
  options.services.actual-server = {
    enable = lib.mkEnableOption "Actual Server";

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Hostname for the Actual Server.";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 25448;
      description = "Port on which the Actual Server should listen.";
    };

    stateDirName = lib.mkOption {
      type = lib.types.str;
      default = "actual-server";
      description = "Name of the directory under /var/lib holding the server's data.";
    };

    upload = {
      fileSizeSyncLimitMB = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File size limit in MB for synchronized files.";
      };

      syncEncryptedFileSizeLimitMB = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File size limit in MB for synchronized encrypted files.";
      };

      fileSizeLimitMB = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "File size limit in MB for file uploads.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.actual-server = {
      description = "Actual Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.actual-server}/bin/actual-server";
        Restart = "always";
        StateDirectory = cfg.stateDirName;
        WorkingDirectory = stateDir;
        DynamicUser = true;
        UMask = "0007";
      };
      environment = {
        NODE_ENV = "production";
        ACTUAL_PORT = toString cfg.port;

        # Actual is actually very bad at configuring it's own paths despite that information being readily available
        ACTUAL_USER_FILES = "${stateDir}/user-files";
        ACTUAL_SERVER_FILES = "${stateDir}/server-files";
        ACTUAL_DATA_DIR = stateDir;

        ACTUAL_UPLOAD_FILE_SYNC_SIZE_LIMIT_MB = toString (cfg.upload.fileSizeSyncLimitMB or "");
        ACTUAL_UPLOAD_SYNC_ENCRYPTED_FILE_SIZE_LIMIT_MB = toString (cfg.upload.syncEncryptedFileSizeLimitMB or "");
        ACTUAL_UPLOAD_FILE_SIZE_LIMIT_MB = toString (cfg.upload.fileSizeLimitMB or "");
      };
    };

    services.nginx.virtualHosts.${cfg.hostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:${toString cfg.port}";
    };
  };
}

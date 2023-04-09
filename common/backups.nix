{ config, lib, ... }:

let
  cfg = config.backup;
  hostname = config.networking.hostName;

  mkBackup = group: paths: {
    repository = "s3:s3.us-west-004.backblazeb2.com/D22TgIt0-main-backup/${group}";
    inherit paths;

    initialize = true;

    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
    };

    pruneOpts = [
      "--keep-daily 7" # one backup for each of the last n days
      "--keep-weekly 5" # one backup for each of the last n weeks
      "--keep-monthly 12" # one backup for each of the last n months
      "--keep-yearly 75" # one backup for each of the last n years
    ];

    environmentFile = "/run/agenix/backblaze-s3-backups";
    passwordFile = "/run/agenix/restic-password";
  };
in
{
  options.backup = {
    group = lib.mkOption {
      default = null;
      type = lib.types.nullOr (lib.types.attrsOf (lib.types.submodule {
        options = {
          paths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = ''
              Paths to backup
            '';
          };
        };
      }));
    };
  };

  config = lib.mkIf (cfg.group != null) {
    services.restic.backups = lib.concatMapAttrs
      (group: groupCfg: {
        ${group} = mkBackup group groupCfg.paths;
      })
      cfg.group;

    age.secrets.backblaze-s3-backups.file = ../secrets/backblaze-s3-backups.age;
    age.secrets.restic-password.file = ../secrets/restic-password.age;
  };
}

{ config, lib, pkgs, ... }:

let
  cfg = config.backup;

  mkRespository = group: "s3:s3.us-west-004.backblazeb2.com/D22TgIt0-main-backup/${group}";

  findmnt = "${pkgs.util-linux}/bin/findmnt";
  mount = "${pkgs.util-linux}/bin/mount";
  umount = "${pkgs.util-linux}/bin/umount";
  btrfs = "${pkgs.btrfs-progs}/bin/btrfs";
  zfs = "/run/current-system/sw/bin/zfs";

  # Creates snapshots and bind mounts them over original paths within the
  # service's mount namespace, so restic sees correct paths but reads frozen data
  snapshotHelperFn = ''
    snapshot_for_path() {
      local group="$1" path="$2" action="$3"
      local pathhash fstype

      pathhash=$(echo -n "$path" | sha256sum | cut -c1-8)
      fstype=$(${findmnt} -n -o FSTYPE -T "$path" 2>/dev/null || echo "unknown")

      case "$fstype" in
        zfs)
          local dataset mount subpath snapname snappath
          dataset=$(${findmnt} -n -o SOURCE -T "$path")
          mount=$(${findmnt} -n -o TARGET -T "$path")
          subpath=''${path#"$mount"}
          [[ "$subpath" != /* ]] && subpath="/$subpath"
          snapname="''${dataset}@restic-''${group}-''${pathhash}"
          snappath="''${mount}/.zfs/snapshot/restic-''${group}-''${pathhash}''${subpath}"
          case "$action" in
            create)
              ${zfs} destroy "$snapname" 2>/dev/null || true
              ${zfs} snapshot "$snapname"
              ${mount} --bind "$snappath" "$path"
              echo "$path"
              ;;
            destroy)
              ${umount} "$path" 2>/dev/null || true
              ${zfs} destroy "$snapname" 2>/dev/null || true
              ;;
          esac
          ;;
        btrfs)
          local mount subpath snapdir snappath
          mount=$(${findmnt} -n -o TARGET -T "$path")
          subpath=''${path#"$mount"}
          [[ "$subpath" != /* ]] && subpath="/$subpath"
          snapdir="/.restic-snapshots/''${group}-''${pathhash}"
          snappath="''${snapdir}''${subpath}"
          case "$action" in
            create)
              ${btrfs} subvolume delete "$snapdir" 2>/dev/null || true
              mkdir -p /.restic-snapshots
              ${btrfs} subvolume snapshot -r "$mount" "$snapdir" >&2
              ${mount} --bind "$snappath" "$path"
              echo "$path"
              ;;
            destroy)
              ${umount} "$path" 2>/dev/null || true
              ${btrfs} subvolume delete "$snapdir" 2>/dev/null || true
              ;;
          esac
          ;;
        *)
          echo "No snapshot support for $fstype ($path), using original" >&2
          [ "$action" = "create" ] && echo "$path"
          ;;
      esac
    }
  '';

  mkBackup = group: paths: {
    repository = mkRespository group;

    dynamicFilesFrom = "cat /run/restic-backup-${group}/paths";

    backupPrepareCommand = ''
      mkdir -p /run/restic-backup-${group}
      : > /run/restic-backup-${group}/paths

      ${snapshotHelperFn}

      for path in ${lib.escapeShellArgs paths}; do
        snapshot_for_path ${lib.escapeShellArg group} "$path" create >> /run/restic-backup-${group}/paths
      done
    '';

    backupCleanupCommand = ''
      ${snapshotHelperFn}

      for path in ${lib.escapeShellArgs paths}; do
        snapshot_for_path ${lib.escapeShellArg group} "$path" destroy
      done

      rm -rf /run/restic-backup-${group}
    '';

    initialize = true;

    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
    };

    extraBackupArgs = [
      ''--exclude-if-present ".nobackup"''
    ];

    # Keeps backups from up to 6 months ago
    pruneOpts = [
      "--keep-daily 7" # one backup for each of the last n days
      "--keep-weekly 5" # one backup for each of the last n weeks
      "--keep-monthly 6" # one backup for each of the last n months
    ];

    environmentFile = "/run/agenix/backblaze-s3-backups";
    passwordFile = "/run/agenix/restic-password";
  };

  # example usage: "sudo restic_samba unlock" (removes lockfile)
  mkResticGroupCmd = group: pkgs.writeShellScriptBin "restic_${group}" ''
    if [ "$EUID" -ne 0 ]
      then echo "Run as root"
      exit
    fi
    . /run/agenix/backblaze-s3-backups
    export AWS_SECRET_ACCESS_KEY
    export AWS_ACCESS_KEY_ID
    export RESTIC_PASSWORD_FILE=/run/agenix/restic-password
    export RESTIC_REPOSITORY="${mkRespository group}"
    exec ${pkgs.restic}/bin/restic "$@"
  '';
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
    assertions = lib.mapAttrsToList (group: _: {
      assertion = config.systemd.services."restic-backups-${group}".enable;
      message = "Expected systemd service 'restic-backups-${group}' not found. The nixpkgs restic module may have changed its naming convention.";
    }) cfg.group;

    services.restic.backups = lib.concatMapAttrs
      (group: groupCfg: {
        ${group} = mkBackup group groupCfg.paths;
      })
      cfg.group;

    # Mount namespace lets us bind mount snapshots over original paths,
    # so restic backs up from frozen snapshots while recording correct paths
    systemd.services = lib.concatMapAttrs
      (group: _: {
        "restic-backups-${group}".serviceConfig.PrivateMounts = true;
      })
      cfg.group;

    age.secrets.backblaze-s3-backups.file = ../secrets/backblaze-s3-backups.age;
    age.secrets.restic-password.file = ../secrets/restic-password.age;

    environment.systemPackages = map mkResticGroupCmd (builtins.attrNames cfg.group);
  };
}

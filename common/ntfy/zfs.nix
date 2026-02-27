{ config, lib, pkgs, ... }:

let
  cfg = config.ntfy-alerts;
  hasZfs = config.boot.supportedFilesystems.zfs or false;
  hasNtfy = config.thisMachine.hasRole."ntfy";

  checkScript = pkgs.writeShellScript "zfs-health-check" ''
    PATH="${lib.makeBinPath [ pkgs.zfs pkgs.coreutils pkgs.gawk pkgs.curl ]}"

    unhealthy=""

    # Check pool health status
    while IFS=$'\t' read -r pool state; do
      if [ "$state" != "ONLINE" ]; then
        unhealthy="$unhealthy"$'\n'"Pool '$pool' is $state"
      fi
    done < <(zpool list -H -o name,health)

    # Check for errors (read, write, checksum) on any vdev
    while IFS=$'\t' read -r pool errors; do
      if [ "$errors" != "No known data errors" ] && [ -n "$errors" ]; then
        unhealthy="$unhealthy"$'\n'"Pool '$pool' has errors: $errors"
      fi
    done < <(zpool status -x 2>/dev/null | awk '
      /pool:/ { pool=$2 }
      /errors:/ { sub(/^[[:space:]]*errors: /, ""); print pool "\t" $0 }
    ')

    # Check for any drives with non-zero error counts
    drive_errors=$(zpool status 2>/dev/null | awk '
      /DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED/ && !/pool:/ && !/state:/ {
        print "  " $0
      }
      /[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+/ {
        if ($3 > 0 || $4 > 0 || $5 > 0) {
          print "  " $1 " (read:" $3 " write:" $4 " cksum:" $5 ")"
        }
      }
    ')
    if [ -n "$drive_errors" ]; then
      unhealthy="$unhealthy"$'\n'"Device errors:"$'\n'"$drive_errors"
    fi

    if [ -n "$unhealthy" ]; then
      message="ZFS health check failed on ${config.networking.hostName}:$unhealthy"

      curl \
        --fail --silent --show-error \
        --max-time 30 --retry 3 \
        -H "Authorization: Bearer $NTFY_TOKEN" \
        -H "Title: ZFS issue on ${config.networking.hostName}" \
        -H "Priority: urgent" \
        -H "Tags: warning" \
        -d "$message" \
        "${cfg.serverUrl}/service-failures"

      echo "$message" >&2
    fi

    echo "All ZFS pools healthy"
  '';
in
{
  config = lib.mkIf (hasZfs && hasNtfy) {
    systemd.services.zfs-health-check = {
      description = "Check ZFS pool health and alert on issues";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "zfs.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/run/agenix/ntfy-token";
        ExecStart = checkScript;
      };
    };

    systemd.timers.zfs-health-check = {
      description = "Periodic ZFS health check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}

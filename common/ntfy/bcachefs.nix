{ config, lib, pkgs, ... }:

# bcachefs health: a member missing or not read-write, the filesystem not
# read-write, entries in its error list, new device I/O errors, or data left
# with fewer replicas than configured. The facts come from the same probe
# that feeds the metrics (common/bcachefs-metrics.nix), so an alert here
# always matches what the dashboard shows. Alerts once per distinct problem
# set and once more on recovery; the sender spools if the network is down.

let
  cfg = config.ntfy-alerts;
  hasBcachefs = config.boot.supportedFilesystems.bcachefs or false;
  hasNtfy = config.thisMachine.hasRole."ntfy";
  host = config.networking.hostName;

  checkScript = pkgs.writeShellScript "bcachefs-health-check" ''
    set -u
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.gnused ]}"
    state="$STATE_DIRECTORY"
    facts=$(${config.bcachefs.probe})
    issues=""   # states: reported when the set changes, and on recovery
    events=""   # counter increases: reported every time they happen
    urgent=0
    : > "$state/io-errors.new"

    add() { issues="$issues"$'\n'"  $1"; }
    event() { events="$events"$'\n'"  $1"; }
    # value of the first sample whose name and labels match a regex
    fact() { awk -v re="$1" '$0 ~ re { print $NF; exit }' <<< "$facts"; }

    # A mounted filesystem the probe says nothing about is itself a problem:
    # a silent probe must never read as healthy.
    for fs in /sys/fs/bcachefs/*/; do
      [ -d "$fs" ] || continue
      u=$(basename "$fs")
      grep -q "^bcachefs_fs_members{fs=\"$u\"}" <<< "$facts" \
        || { add "filesystem ''${u:0:8}: the metrics probe produced no facts for it"; urgent=1; }
    done

    for uuid in $(grep -o '^bcachefs_fs_members{fs="[^"]*"' <<< "$facts" | cut -d'"' -f2); do
      short=''${uuid:0:8}
      F="fs=\"$uuid\""

      members=$(fact "^bcachefs_fs_members[{]$F[}]")
      present=$(fact "^bcachefs_fs_members_present[{]$F[}]")
      if [ "''${members:-0}" -gt "''${present:-0}" ]; then
        add "filesystem $short: only $present of $members member devices present"; urgent=1
      fi

      if [ "$(fact "^bcachefs_fs_rw[{]$F[}]")" != 1 ]; then
        add "filesystem $short is not read-write"; urgent=1
      fi

      errs=$(fact "^bcachefs_fs_errors[{]$F[}]")
      if [ "''${errs:-0}" -gt 0 ]; then
        add "filesystem $short lists $errs error(s): $(head -n 5 "/sys/fs/bcachefs/$uuid/errors" | tr '\n' ';')"; urgent=1
      fi

      deg=$(awk -v f="$F" '$0 ~ "^bcachefs_fs_data_bytes[{]"f"," && $0 !~ /degraded="0"/ { s += $NF } END { printf "%d\n", s }' <<< "$facts")
      if [ "''${deg:-0}" -gt 0 ]; then
        add "filesystem $short has $(numfmt --to=iec "$deg") of data with fewer replicas than configured"
      fi

      for label in $(grep -o "^bcachefs_device_rw{$F,label=\"[^\"]*\"" <<< "$facts" | sed 's/.*label="//; s/"$//'); do
        D="$F,label=\"$label\""
        if [ "$(fact "^bcachefs_device_rw[{]$D[}]")" != 1 ]; then
          st=$(grep -o "^bcachefs_device_state{$D,state=\"[^\"]*\"" <<< "$facts" | sed 's/.*state="//; s/"$//')
          add "device $label of $short is ''${st:-not read-write}"; urgent=1
        fi
        er=$(fact "^bcachefs_device_io_errors_total[{]$D,type=\"read\"[}]")
        ew=$(fact "^bcachefs_device_io_errors_total[{]$D,type=\"write\"[}]")
        ec=$(fact "^bcachefs_device_io_errors_total[{]$D,type=\"checksum\"[}]")
        key="$uuid/$label"
        read -r pr pw pc <<< "$(awk -v k="$key" '$1==k { print $2, $3, $4 }' "$state/io-errors" 2>/dev/null)"
        pr=''${pr:-0} pw=''${pw:-0} pc=''${pc:-0}
        if [ "''${er:-0}" -gt "$pr" ] || [ "''${ew:-0}" -gt "$pw" ] || [ "''${ec:-0}" -gt "$pc" ]; then
          event "device $label of $short: I/O errors read $er (+$((er - pr))) write $ew (+$((ew - pw))) checksum $ec (+$((ec - pc)))"
        fi
        echo "$key ''${er:-0} ''${ew:-0} ''${ec:-0}" >> "$state/io-errors.new"
      done
    done
    mv "$state/io-errors.new" "$state/io-errors"

    prev_issues=$(cat "$state/last-issues" 2>/dev/null || true)
    printf '%s' "$issues" > "$state/last-issues"

    if [ -n "$events" ]; then
      echo "bcachefs events on ${host}:$events"
      ${cfg.notify} service-failures high warning "bcachefs I/O errors on ${host}" "New bcachefs I/O errors on ${host}:$events"
    fi

    if [ -n "$issues" ]; then
      echo "bcachefs issues on ${host}:$issues"
      if [ "$issues" != "$prev_issues" ]; then
        if [ "$urgent" = 1 ]; then prio=urgent; tags=rotating_light; else prio=high; tags=warning; fi
        ${cfg.notify} service-failures "$prio" "$tags" "bcachefs problem on ${host}" "bcachefs health check on ${host}:$issues"
      fi
    else
      echo "bcachefs healthy"
      if [ -n "$prev_issues" ]; then
        ${cfg.notify} service-failures low white_check_mark "bcachefs recovered on ${host}" "Earlier bcachefs problems on ${host} have cleared."
      fi
    fi
  '';
in
{
  config = lib.mkIf (hasBcachefs && hasNtfy) {
    systemd.services.bcachefs-health-check = {
      description = "Check bcachefs filesystems and alert on degraded state or errors";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/run/agenix/ntfy-token";
        StateDirectory = "bcachefs-health-check";
        ExecStart = checkScript;
      };
    };

    systemd.timers.bcachefs-health-check = {
      description = "Periodic bcachefs health check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "90s";
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };
  };
}

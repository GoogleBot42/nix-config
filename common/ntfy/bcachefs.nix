{ config, lib, pkgs, ... }:

# bcachefs health: a member missing or not read-write, the filesystem not
# read-write, entries in its error list, new device I/O errors, or data left
# with fewer replicas than configured. Alerts once per distinct problem set
# and once more on recovery; the sender spools if the network is not up yet.

let
  cfg = config.ntfy-alerts;
  hasBcachefs = config.boot.supportedFilesystems.bcachefs or false;
  hasNtfy = config.thisMachine.hasRole."ntfy";
  host = config.networking.hostName;

  checkScript = pkgs.writeShellScript "bcachefs-health-check" ''
    set -u
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.util-linux pkgs.bcachefs-tools ]}"
    state="$STATE_DIRECTORY"
    issues=""
    urgent=0
    : > "$state/io-errors.new"

    add() { issues="$issues"$'\n'"  $1"; }

    for fs in /sys/fs/bcachefs/*/; do
      [ -d "$fs" ] || continue
      uuid=$(basename "$fs")
      short=''${uuid:0:8}

      blk=""
      for d in "$fs"dev-*/; do
        [ -d "$d" ] || continue
        b=$(basename "$(readlink "$d/block")")
        [ -n "$b" ] && { blk=$b; break; }
      done
      present=$(ls -d "$fs"dev-*/ 2>/dev/null | wc -l)
      members=0
      [ -n "$blk" ] && members=$(bcachefs show-super "/dev/$blk" 2>/dev/null | awk '/^Devices:/{print $2}')
      if [ "''${members:-0}" -gt "$present" ]; then
        add "filesystem $short: only $present of $members member devices present"; urgent=1
      fi

      if ! grep -qw rw "$fs/internal/flags"; then
        add "filesystem $short is not read-write (flags: $(tr '\n' ' ' < "$fs/internal/flags"))"; urgent=1
      fi

      errs=$(grep -c . "$fs/errors" 2>/dev/null || true)
      if [ "''${errs:-0}" -gt 0 ]; then
        add "filesystem $short lists $errs error(s): $(head -n 5 "$fs/errors" | tr '\n' ';')"; urgent=1
      fi

      for d in "$fs"dev-*/; do
        [ -d "$d" ] || continue
        label=$(cat "$d/label")
        st=$(grep -o '\[[a-z]*\]' "$d/state" | tr -d '[]')
        [ "$st" = rw ] || { add "device $label of $short is $st"; urgent=1; }

        read -r er ew ec < <(awk '
          /since filesystem creation/ { f=1; next }
          f && /read:/ { r=$2 } f && /write:/ { w=$2 }
          f && /checksum:/ { sub(/checksum:/, ""); c=$1; print r+0, w+0, c+0; exit }' "$d/io_errors")
        key="$uuid/$label"
        prev=$(awk -v k="$key" '$1==k {print $2, $3, $4}' "$state/io-errors" 2>/dev/null)
        read -r pr pw pc <<< "''${prev:-0 0 0}"
        if [ "$er" -gt "$pr" ] || [ "$ew" -gt "$pw" ] || [ "$ec" -gt "$pc" ]; then
          add "device $label of $short: I/O errors read $er (+$((er - pr))) write $ew (+$((ew - pw))) checksum $ec (+$((ec - pc)))"
        fi
        echo "$key $er $ew $ec" >> "$state/io-errors.new"
      done

      mp=$(findmnt -t bcachefs -no TARGET,SOURCE | awk -v d="/dev/$blk" 'index($2, d) { print $1; exit }')
      if [ -n "$mp" ]; then
        deg=$(bcachefs fs usage "$mp" 2>/dev/null | awk '
          /^[[:space:]]+undegraded/ { acct=1; next }
          acct && /^Device label/ { acct=0 }
          acct && /^[0-9]+x:/ { for (i = 3; i <= NF; i++) if ($i + 0 > 0) sum += $i }
          END { printf "%d\n", sum + 0 }')
        if [ "''${deg:-0}" -gt 0 ]; then
          add "filesystem $short has $(numfmt --to=iec "$deg") of data with fewer replicas than configured"
        fi
      fi
    done
    mv "$state/io-errors.new" "$state/io-errors"

    prev_issues=$(cat "$state/last-issues" 2>/dev/null || true)
    printf '%s' "$issues" > "$state/last-issues"

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

{ config, lib, pkgs, ... }:

# bcachefs metrics for the fleet scraper, through node_exporter's textfile
# collector: per device state, I/O error counters, latency statistics and
# bytes moved by data type; per filesystem size, free and writable space,
# data by replica level (degraded data has fewer replicas than configured),
# members present and the reconcile backlog. Sources are sysfs and
# `bcachefs fs usage`.

let
  textfileDir = config.services.prometheus.exporters.node.textfileDirectory;
  hasBcachefs = config.boot.supportedFilesystems.bcachefs or false;

  # Prints every fact as Prometheus text on stdout. The metrics timer saves
  # it for node_exporter; the ntfy health check (common/ntfy/bcachefs.nix)
  # reads the same output, so alerts and dashboards cannot disagree.
  probe = pkgs.writeShellScript "bcachefs-probe" ''
    set -u
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.util-linux pkgs.jq pkgs.bcachefs-tools ]}"
    m() { printf '%s\n' "$1"; }

    # "23.0G" -> bytes, as bcachefs prints human sizes (binary units)
    hr2bytes() {
      awk -v s="$1" 'BEGIN {
        n = s + 0; u = substr(s, length(s), 1)
        if (u == "K") n *= 1024; else if (u == "M") n *= 1024^2; else if (u == "G") n *= 1024^3
        else if (u == "T") n *= 1024^4; else if (u == "P") n *= 1024^5
        printf "%.0f\n", n }'
    }

    for fs in /sys/fs/bcachefs/*/; do
      [ -d "$fs" ] || continue
      uuid=$(basename "$fs")
      L="fs=\"$uuid\""

      blk=""
      for d in "$fs"dev-*/; do
        [ -d "$d" ] || continue
        b=$(basename "$(readlink "$d/block")"); [ -n "$b" ] && { blk=$b; break; }
      done
      present=$(ls -d "$fs"dev-*/ 2>/dev/null | wc -l)
      members=$present
      [ -n "$blk" ] && members=$(bcachefs show-super "/dev/$blk" 2>/dev/null | awk '/^Devices:/{print $2}')
      m "bcachefs_fs_members{$L} ''${members:-$present}"
      m "bcachefs_fs_members_present{$L} $present"
      m "bcachefs_fs_rw{$L} $(grep -qw rw "$fs/internal/flags" && echo 1 || echo 0)"
      m "bcachefs_fs_errors{$L} $(grep -c . "$fs/errors" 2>/dev/null || echo 0)"
      rem=$(awk '/io wait remaining:/ { print $4 }' "$fs/reconcile_status" 2>/dev/null)
      [ -n "$rem" ] && m "bcachefs_fs_reconcile_wait_remaining_bytes{$L} $(hr2bytes "$rem")"

      for d in "$fs"dev-*/; do
        [ -d "$d" ] || continue
        label=$(cat "$d/label")
        DL="$L,label=\"$label\""
        st=$(grep -o '\[[a-z]*\]' "$d/state" | tr -d '[]')
        m "bcachefs_device_state{$DL,state=\"$st\"} 1"
        m "bcachefs_device_rw{$DL} $([ "$st" = rw ] && echo 1 || echo 0)"
        m "bcachefs_device_durability{$DL} $(cat "$d/durability")"
        awk -v l="$DL" '
          /since filesystem creation/ { f=1; next }
          f && /read:/ { printf "bcachefs_device_io_errors_total{%s,type=\"read\"} %d\n", l, $2 }
          f && /write:/ { printf "bcachefs_device_io_errors_total{%s,type=\"write\"} %d\n", l, $2 }
          f && /checksum:/ { sub(/checksum:/, ""); printf "bcachefs_device_io_errors_total{%s,type=\"checksum\"} %d\n", l, $1; exit }' "$d/io_errors"
        jq -r --arg l "$DL" '
          to_entries[] | .key as $dir | .value | to_entries[]
          | "bcachefs_device_io_bytes_total{\($l),direction=\"\($dir)\",data_type=\"\(.key)\"} \(.value)"' "$d/io_done"
        for op in read write; do
          jq -r --arg l "$DL" --arg op "$op" '
            "bcachefs_device_io_count_total{\($l),op=\"\($op)\"} \(.count)",
            "bcachefs_device_io_latency_seconds{\($l),op=\"\($op)\",stat=\"mean\"} \(.duration_ns.mean / 1e9)",
            "bcachefs_device_io_latency_seconds{\($l),op=\"\($op)\",stat=\"max\"} \(.duration_ns.max / 1e9)",
            "bcachefs_device_io_latency_seconds{\($l),op=\"\($op)\",stat=\"stddev\"} \(.duration_ns.stddev / 1e9)",
            "bcachefs_device_io_latency_seconds{\($l),op=\"\($op)\",stat=\"ewma_mean\"} \(.duration_ewma_ns.mean / 1e9)"' \
            "$d/io_latency_stats_''${op}_json" 2>/dev/null
        done
      done

      mp=$(findmnt -t bcachefs -no TARGET,SOURCE | awk -v d="/dev/$blk" 'index($2, d) { print $1; exit }')
      if [ -n "$mp" ]; then
        bcachefs fs usage "$mp" 2>/dev/null | awk -v l="$L" '
          /^Size:/ { printf "bcachefs_fs_size_bytes{%s} %s\n", l, $2 }
          /^Used:/ { printf "bcachefs_fs_used_bytes{%s} %s\n", l, $2 }
          /^Online reserved:/ { printf "bcachefs_fs_online_reserved_bytes{%s} %s\n", l, $3 }
          /^Free:/ { printf "bcachefs_fs_free_bytes{%s} %s\nbcachefs_fs_writable_bytes{%s} %s\n", l, $2, l, $3 }
          /^[[:space:]]+undegraded/ { acct=1; for (i = 1; i <= NF; i++) hdr[i+1] = $i; next }
          acct && /^Device label/ { acct=0 }
          acct && /^[0-9]+x:/ { r=$1; sub(/:/, "", r); for (i = 2; i <= NF; i++) {
            d = (hdr[i] == "undegraded") ? "0" : hdr[i]; sub(/x$/, "", d)
            printf "bcachefs_fs_data_bytes{%s,replicas=\"%s\",degraded=\"%s\"} %s\n", l, r, d, $i } }
          /\(device [0-9]+\):/ { lab=$1; printf "bcachefs_device_size_bytes{%s,label=\"%s\"} %s\nbcachefs_device_used_bytes{%s,label=\"%s\"} %s\n", l, lab, $(NF-2), l, lab, $(NF-1) }
        '
      fi
      m "bcachefs_metrics_timestamp_seconds{} $(date +%s)"
    done
  '';

  writer = pkgs.writeShellScript "bcachefs-metrics" ''
    set -u
    out="${textfileDir}/bcachefs.prom"
    ${probe} > "$out.tmp" && mv "$out.tmp" "$out"
  '';
in
{
  options.bcachefs.probe = lib.mkOption {
    type = lib.types.path;
    default = probe;
    readOnly = true;
    description = "Script printing every bcachefs fact as Prometheus text.";
  };

  config = lib.mkIf (hasBcachefs && config.services.prometheus.exporters.node.enable) {
    systemd.services.bcachefs-metrics = {
      description = "Export bcachefs metrics for node_exporter";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = writer;
      };
    };
    systemd.timers.bcachefs-metrics = {
      description = "Refresh bcachefs metrics";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "30s";
        AccuracySec = "5s";
      };
    };
  };
}

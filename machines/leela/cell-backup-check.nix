{ config, lib, pkgs, ... }:

# Hourly end-to-end check of the cellular backup uplink (networking.nix: the
# GRE tunnel to the UniFi 5G Backup): a ping and a small HTTPS fetch bound to
# the tunnel, plus the carrier-side public address, exported through
# node_exporter's textfile collector. A run moves a few kilobytes and is
# never a speed test. The unit exits 0 when the uplink is down: the metric is
# the result, and a failed unit would raise a service-failure alert every
# hour. Instead a change between usable and unusable is announced once on
# ntfy, so a dead backup is known before the outage that needs it.

let
  textfileDir = config.services.prometheus.exporters.node.textfileDirectory;
  tunnel = "gre-cell";
  hasNtfy = config.thisMachine.hasRole."ntfy";

  check = pkgs.writeShellApplication {
    name = "cell-backup-check";
    runtimeInputs = with pkgs; [ coreutils gawk gnugrep iputils curl ];
    text = ''
      out=${textfileDir}/cell-backup-check.prom
      # Last result, so a change of state is announced once, not every hour.
      last=$STATE_DIRECTORY/last-ok
      now=$(date +%s)

      ping_ok=0 rtt=""
      if ping_out=$(ping -n -q -c 3 -W 2 -I ${tunnel} 1.1.1.1 2> /dev/null); then
        # "rtt min/avg/max/mdev = 10.1/12.3/14.5/1.2 ms"; avg is field 5.
        rtt=$(awk -F/ '/^rtt/ { printf "%.6f", $5 / 1000 }' <<< "$ping_out")
        [ -n "$rtt" ] && ping_ok=1
      fi

      http_ok=0 http_code="" http_time=""
      # DNS for the name goes over whichever uplink is active; the request
      # itself is bound to the tunnel.
      http_out=$(curl -4 --interface ${tunnel} --max-time 20 -sS -o /dev/null \
        -w '%{http_code} %{time_total}' https://www.google.com/generate_204 2> /dev/null) || true
      read -r http_code http_time <<< "$http_out" || true
      [ "$http_code" = 204 ] && http_ok=1
      [[ "$http_time" =~ ^[0-9]+(\.[0-9]+)?$ ]] || http_time=""

      public_ip=$(curl -4 --interface ${tunnel} --max-time 20 -sS https://ifconfig.co/ip 2> /dev/null | tr -d '[:space:]') || true
      [[ "$public_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || public_ip=""

      ok=0
      [ "$ping_ok" = 1 ] && [ "$http_ok" = 1 ] && ok=1

      {
        echo '# HELP cell_backup_check_ok 1 when both the ping and the HTTPS fetch through the cellular tunnel succeeded.'
        echo '# TYPE cell_backup_check_ok gauge'
        echo "cell_backup_check_ok $ok"
        echo '# HELP cell_backup_check_ping_ok 1 when 1.1.1.1 answered a ping through the cellular tunnel.'
        echo '# TYPE cell_backup_check_ping_ok gauge'
        echo "cell_backup_check_ping_ok $ping_ok"
        echo '# HELP cell_backup_check_http_ok 1 when an HTTPS fetch through the cellular tunnel returned 204.'
        echo '# TYPE cell_backup_check_http_ok gauge'
        echo "cell_backup_check_http_ok $http_ok"
        if [ "$ping_ok" = 1 ]; then
          echo '# HELP cell_backup_check_ping_rtt_seconds Average ping round trip through the cellular tunnel.'
          echo '# TYPE cell_backup_check_ping_rtt_seconds gauge'
          echo "cell_backup_check_ping_rtt_seconds $rtt"
        fi
        if [ -n "$http_time" ]; then
          echo '# HELP cell_backup_check_http_duration_seconds Total time of the HTTPS fetch through the cellular tunnel.'
          echo '# TYPE cell_backup_check_http_duration_seconds gauge'
          echo "cell_backup_check_http_duration_seconds $http_time"
        fi
        echo '# HELP cell_backup_check_timestamp_seconds When the check last ran.'
        echo '# TYPE cell_backup_check_timestamp_seconds gauge'
        echo "cell_backup_check_timestamp_seconds $now"
        if [ -n "$public_ip" ]; then
          echo '# HELP cell_backup_check_public_ip_info Public address the carrier presents for the cellular uplink.'
          echo '# TYPE cell_backup_check_public_ip_info gauge'
          echo "cell_backup_check_public_ip_info{ip=\"$public_ip\"} 1"
        fi
      } > "$out.tmp"
      mv "$out.tmp" "$out"

      summary="ok=$ok ping=$ping_ok rtt=''${rtt:-n/a}s http=''${http_code:-none} time=''${http_time:-n/a}s ip=''${public_ip:-unknown}"
      echo "cellular backup: $summary"

      previous=$(cat "$last" 2> /dev/null || echo unknown)
      if [ "$ok" != "$previous" ]; then
        echo "$ok" > "$last"
        ${lib.optionalString hasNtfy ''
          if [ "$ok" = 1 ]; then
            [ "$previous" = 0 ] && ${config.ntfy-alerts.notify} service-failures default "white_check_mark,signal_strength" \
              "Cellular backup usable again on ${config.networking.hostName}" "$summary"
          else
            ${config.ntfy-alerts.notify} service-failures high "warning,signal_strength" \
              "Cellular backup NOT usable on ${config.networking.hostName}" "The hourly check through the modem failed: $summary"
          fi
        ''}
      fi
    '';
  };
in
{
  systemd.services.cell-backup-check = {
    description = "Check the cellular backup uplink end to end";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe check;
      StateDirectory = "cell-backup-check";
    } // lib.optionalAttrs hasNtfy {
      EnvironmentFile = "/run/agenix/ntfy-token";
    };
  };

  systemd.timers.cell-backup-check = {
    description = "Hourly check of the cellular backup uplink";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      RandomizedDelaySec = "5min";
      Persistent = false;
    };
  };
}

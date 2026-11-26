{ config, lib, pkgs, ... }:

# WAN failover for a router with a second uplink (networking.nix: the cellular
# GRE tunnel). The watchdog probes the primary WAN by pinging public anycast
# resolvers out of that interface; while they stay silent it adds a default
# route through the backup to the main table at a metric that beats the
# primary's, and withdraws it once the primary answers again. A route rather
# than a policy rule because Tailscale pins its own packets to the main table
# with fwmark rules, so only a main-table route keeps the tailnet up as well.
# Link state alone is not enough on a cable modem: the link stays up while the
# upstream is dead, so only an end-to-end probe tells the truth. The switch
# is only ever made onto a backup that answers at that moment.

let
  cfg = config.router.wanFailover;
  hasNtfy = config.thisMachine.hasRole."ntfy";
  textfileDir = config.services.prometheus.exporters.node.textfileDirectory;

  watchdog = pkgs.writeShellApplication {
    name = "wan-failover";
    runtimeInputs = with pkgs; [ coreutils iproute2 iputils conntrack-tools gnugrep ];
    text = ''
      primary=${cfg.primaryInterface}
      backup=${cfg.backupInterface}
      gateway=${cfg.backupGateway}
      metric=${toString cfg.backupMetric}
      targets=(${lib.concatStringsSep " " cfg.probeTargets})
      metrics=${textfileDir}/wan-failover.prom

      state=primary fails=0 oks=0 backup_ok=0 transitions=0 last_change=$(date +%s) tick=0
      backup_misses=0 backup_silent=0 backup_first_miss=0

      # One answering target is enough; -I binds the probe to the interface so
      # it cannot sneak out the other uplink.
      probe() {
        local t
        for t in "''${targets[@]}"; do
          ping -n -q -c 1 -W ${toString cfg.probeTimeoutSec} -I "$1" "$t" > /dev/null 2>&1 && return 0
        done
        return 1
      }

      engage() { ip -4 route replace default via "$gateway" dev "$backup" onlink metric "$metric"; }
      disengage() { ip -4 route del default via "$gateway" dev "$backup" metric "$metric" 2> /dev/null || true; }

      # Masqueraded flows carry the old uplink's address; drop them so the
      # clients' retries are NATed afresh through the uplink now in use.
      flush_nat() { conntrack -D --src-nat > /dev/null 2>&1 || true; }

      notify() {
        ${lib.optionalString hasNtfy ''
          ${config.ntfy-alerts.notify} service-failures "$1" "$2" "$3" "$4"
        ''}
        :
      }

      # Every backup probe passes through here, so the backup going silent or
      # answering again is announced within a probe interval instead of waiting
      # for the five-minute end-to-end check. Two misses in a row before the
      # alarm and a minute of silence: one lost ping is noise on a cellular link,
      # and while failed over the backup is probed every round.
      track_backup() {
        local now; now=$(date +%s)
        if [ "$backup_ok" -eq 1 ]; then
          if [ "$backup_silent" -eq 1 ]; then
            backup_silent=0
            echo "backup $backup answers again after $(( (now - backup_first_miss) / 60 )) min of silence"
            notify default "white_check_mark,signal_strength" "Cellular backup answering again on ${config.networking.hostName}" \
              "$backup answered a probe again after $(( (now - backup_first_miss) / 60 )) min of silence."
          fi
          backup_misses=0
        else
          [ "$backup_misses" -eq 0 ] && backup_first_miss=$now
          backup_misses=$((backup_misses + 1))
          if [ "$backup_silent" -eq 0 ] && [ "$backup_misses" -ge ${toString cfg.backupSilentAfter} ] \
            && [ $((now - backup_first_miss)) -ge ${toString cfg.backupSilentSec} ]; then
            backup_silent=1
            echo "backup $backup unanswered $backup_misses probes in a row since $(date -d "@$backup_first_miss" +%H:%M:%S)"
            notify high "warning,signal_strength" "Cellular backup stopped answering on ${config.networking.hostName}" \
              "$backup did not answer $backup_misses probes in a row, the first at $(date -d "@$backup_first_miss" +%H:%M:%S). The five-minute check will say which layer failed."
          fi
        fi
      }
      probe_backup() {
        if probe "$backup"; then backup_ok=1; else backup_ok=0; fi
        track_backup
      }

      write_metrics() {
        local active=0 primary_ok=0
        [ "$state" = backup ] && active=1
        [ "$fails" -eq 0 ] && primary_ok=1
        {
          echo '# HELP wan_failover_active 1 while LAN traffic is routed through the backup uplink.'
          echo '# TYPE wan_failover_active gauge'
          echo "wan_failover_active $active"
          echo '# HELP wan_probe_ok 1 when the last probe out of the interface was answered.'
          echo '# TYPE wan_probe_ok gauge'
          echo "wan_probe_ok{interface=\"$primary\"} $primary_ok"
          echo "wan_probe_ok{interface=\"$backup\"} $backup_ok"
          echo '# HELP wan_backup_silent 1 while the backup uplink has stopped answering its probes.'
          echo '# TYPE wan_backup_silent gauge'
          echo "wan_backup_silent $backup_silent"
          echo '# HELP wan_failover_transitions_total Switches between the uplinks since the watchdog started.'
          echo '# TYPE wan_failover_transitions_total counter'
          echo "wan_failover_transitions_total $transitions"
          echo '# HELP wan_failover_last_change_timestamp_seconds When the active uplink last changed.'
          echo '# TYPE wan_failover_last_change_timestamp_seconds gauge'
          echo "wan_failover_last_change_timestamp_seconds $last_change"
        } > "$metrics.tmp"
        mv "$metrics.tmp" "$metrics"
      }

      # A restart must not leave a stale route from a previous run behind.
      disengage

      while :; do
        if probe "$primary"; then fails=0; oks=$((oks + 1)); else oks=0; fails=$((fails + 1)); fi

        # The backup is metered; probe it rarely while it is idle. A failing
        # primary probes it on demand below.
        if [ "$state" = backup ] || { [ "$fails" -eq 0 ] && [ $((tick % ${toString cfg.backupProbeEvery})) -eq 0 ]; }; then
          probe_backup
        fi
        tick=$((tick + 1))

        case $state in
          primary)
            if [ "$fails" -ge ${toString cfg.failAfter} ]; then
              # Switch only onto a backup that answers right now. If both are
              # dead nothing is gained, and if the primary probe is the one
              # that is wrong, staying put is what keeps the LAN online.
              probe_backup
              if [ "$backup_ok" -eq 1 ]; then
                echo "primary $primary unanswered $fails times; routing through $backup"
                engage; flush_nat
                state=backup transitions=$((transitions + 1)) last_change=$(date +%s)
                notify high "warning,signal_strength" "WAN failover on ${config.networking.hostName}" \
                  "$primary stopped answering; traffic now goes through $backup."
              else
                if [ $((fails % 30)) -eq 0 ]; then
                  echo "primary $primary unanswered $fails times and $backup does not answer either; staying on $primary"
                fi
              fi
            fi
            ;;
          backup)
            # Back to the primary after a steady run of answers, or at the
            # first answer when the backup has died underneath us: a dead
            # backup is never worth waiting out a flap for.
            if [ "$oks" -ge ${toString cfg.recoverAfter} ] || { [ "$oks" -ge 1 ] && [ "$backup_ok" -eq 0 ]; }; then
              echo "primary $primary answered $oks times (backup probe ok=$backup_ok); routing through it again"
              disengage; flush_nat
              state=primary transitions=$((transitions + 1)) last_change=$(date +%s)
              notify default "white_check_mark" "WAN restored on ${config.networking.hostName}" \
                "$primary answers again; traffic left $backup."
            else
              if [ "$backup_ok" -eq 0 ] && [ $((fails % 30)) -eq 0 ]; then
                echo "both $primary and $backup unanswered; staying on $backup until either answers"
              fi
              # Re-assert in case networkd or an admin reloaded the routes.
              engage
            fi
            ;;
        esac

        write_metrics
        sleep ${toString cfg.intervalSec}
      done
    '';
  };
in
{
  options.router.wanFailover = {
    enable = lib.mkEnableOption "probe-driven failover from the primary WAN to a backup uplink";

    primaryInterface = lib.mkOption {
      type = lib.types.str;
      description = "Interface carrying the primary default route (in the main table).";
    };

    backupInterface = lib.mkOption {
      type = lib.types.str;
      description = "Interface the backup default route goes out of; probes are bound to it.";
    };

    backupGateway = lib.mkOption {
      type = lib.types.str;
      description = "Next hop of the backup default route (on-link).";
    };

    backupMetric = lib.mkOption {
      type = lib.types.ints.positive;
      default = 512;
      description = "Metric of the backup default route while failed over; must beat the primary's.";
    };

    probeTargets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "1.1.1.1" "8.8.8.8" "9.9.9.9" ];
      description = "Addresses pinged to judge an uplink; one answer counts as healthy.";
    };

    probeTimeoutSec = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
    };

    intervalSec = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Seconds between probe rounds.";
    };

    failAfter = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Consecutive failed rounds before switching to the backup.";
    };

    recoverAfter = lib.mkOption {
      type = lib.types.ints.positive;
      default = 15;
      description = "Consecutive good rounds before switching back; longer than failAfter so a flapping uplink does not bounce clients.";
    };

    backupProbeEvery = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Probe the (metered) backup only every N rounds while it is idle.";
    };

    backupSilentAfter = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Consecutive unanswered backup probes before the backup is announced silent (one probe a minute while idle).";
    };

    backupSilentSec = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds since the first unanswered backup probe before the backup is announced silent.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.wan-failover = {
      description = "WAN failover watchdog";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "nftables.service" ];
      serviceConfig = {
        ExecStart = lib.getExe watchdog;
        Restart = "always";
        RestartSec = 5;
      } // lib.optionalAttrs hasNtfy {
        EnvironmentFile = "/run/agenix/ntfy-token";
      };
    };
  };
}

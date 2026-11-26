{ config, lib, pkgs, ... }:

# Five-minutely end-to-end check of the cellular backup uplink (networking.nix: the
# GRE tunnel to the UniFi 5G Backup), layer by layer so a failure names the
# part that broke: the router's VLAN link, the modem answering on the LAN
# (ARP), the GRE tunnel passing a ping, and an HTTPS fetch through it, plus
# the carrier-side public address and when the modem last re-joined the LAN
# (a fresh DHCP discover is a modem reboot or an Ethernet link bounce). All of
# it goes to node_exporter's textfile collector. A run moves a few kilobytes
# and is never a speed test. The unit exits 0 when the uplink is down: the
# metric is the result, and a failed unit would raise a service-failure alert
# every run. Instead a change between usable and unusable is announced once
# on ntfy, with the layer that failed, so a dead backup is known and
# understood before the outage that needs it.

let
  textfileDir = config.services.prometheus.exporters.node.textfileDirectory;
  # The modem's VLAN, address and tunnel as networking.nix defines them.
  lan = "br-cell";
  modem = "192.168.14.2";
  tunnel = "gre-cell";
  hasNtfy = config.thisMachine.hasRole."ntfy";

  check = pkgs.writeShellApplication {
    name = "cell-backup-check";
    runtimeInputs = with pkgs; [ coreutils gawk gnugrep iputils curl systemd ];
    text = ''
      out=${textfileDir}/cell-backup-check.prom
      # Last result, so a change of state is announced once, not every run.
      last=$STATE_DIRECTORY/last-ok
      # Tunnel receive counter at the last run: packets that came back through
      # the tunnel since then tell a dead tunnel from a carrier dropping pings.
      last_rx=$STATE_DIRECTORY/last-rx-packets
      now=$(date +%s)

      # 1. The router's own link into the modem's VLAN (the trunk behind it).
      link_ok=0
      [ "$(cat /sys/class/net/${lan}/carrier 2> /dev/null)" = 1 ] && link_ok=1

      # 2. The modem on the LAN: ARP needs nothing from its firmware.
      modem_ok=0
      arping -c 2 -w 3 -I ${lan} ${modem} > /dev/null 2>&1 && modem_ok=1

      # When the modem last asked for its lease anew: a reboot (RAM-only
      # rootfs, so a discover with no address) or an Ethernet link bounce
      # (netifd restarts the client, which asks for its old address).
      rejoin_at="" rejoin_kind=""
      rejoin_line=$(journalctl -u dnsmasq -o short-iso --no-pager --since "7 days ago" 2> /dev/null \
        | grep -F "DHCPDISCOVER(${lan})" | tail -1) || true
      if [ -n "$rejoin_line" ]; then
        rejoin_at=$(date -d "$(cut -d' ' -f1 <<< "$rejoin_line")" +%s 2> /dev/null) || rejoin_at=""
        if grep -qF "DHCPDISCOVER(${lan}) ${modem}" <<< "$rejoin_line"; then
          rejoin_kind="link bounce"
        else
          rejoin_kind="reboot"
        fi
      fi

      # 3. Through the tunnel.
      rx_now=$(cat /sys/class/net/${tunnel}/statistics/rx_packets 2> /dev/null || echo 0)
      rx_prev=$(cat "$last_rx" 2> /dev/null || echo "$rx_now")
      echo "$rx_now" > "$last_rx"
      rx_delta=$((rx_now - rx_prev))
      [ "$rx_delta" -lt 0 ] && rx_delta=0

      ping_ok=0 rtt=""
      if ping_out=$(ping -n -q -c 3 -W 2 -I ${tunnel} 1.1.1.1 2> /dev/null); then
        # "rtt min/avg/max/mdev = 10.1/12.3/14.5/1.2 ms"; avg is field 5.
        rtt=$(awk -F/ '/^rtt/ { printf "%.6f", $5 / 1000 }' <<< "$ping_out")
        [ -n "$rtt" ] && ping_ok=1
      fi

      # 4. The Internet through the tunnel. DNS for the name goes over whichever
      # uplink is active; the request itself is bound to the tunnel.
      http_ok=0 http_code="" http_time=""
      http_out=$(curl -4 --interface ${tunnel} --max-time 20 -sS -o /dev/null \
        -w '%{http_code} %{time_total}' https://www.google.com/generate_204 2> /dev/null) || true
      read -r http_code http_time <<< "$http_out" || true
      [ "$http_code" = 204 ] && http_ok=1
      [[ "$http_time" =~ ^[0-9]+(\.[0-9]+)?$ ]] || http_time=""

      public_ip=""
      if [ "$http_ok" = 1 ]; then
        public_ip=$(curl -4 --interface ${tunnel} --max-time 20 -sS https://ifconfig.co/ip 2> /dev/null | tr -d '[:space:]') || true
        [[ "$public_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || public_ip=""
      fi

      ok=0
      [ "$ping_ok" = 1 ] && [ "$http_ok" = 1 ] && ok=1

      # The first failed layer is the reason; everything behind it is moot.
      if [ "$ok" = 1 ]; then
        reason="usable end to end"
      elif [ "$link_ok" = 0 ]; then
        reason="leela's ${lan} link is down: the trunk or switch on the router side, not the modem"
      elif [ "$modem_ok" = 0 ]; then
        reason="the modem does not answer ARP at ${modem}: it is powered off, rebooting, or its Ethernet link (cable, PoE, switch port) is down"
      elif [ "$ping_ok" = 0 ] && [ "$http_ok" = 0 ]; then
        if [ "$rx_delta" -eq 0 ]; then
          reason="the modem is on the LAN but nothing comes back through the GRE tunnel: its cellular side (signal, SIM, carrier) is down or the tunnel is not peered"
        else
          reason="the modem is on the LAN and the tunnel carries traffic, but neither ping nor HTTPS get through: the cellular data path is broken"
        fi
      elif [ "$ping_ok" = 0 ]; then
        reason="HTTPS works through the tunnel but pings are lost: the carrier is dropping ICMP, the link itself is usable"
      else
        reason="pings pass through the tunnel but the HTTPS fetch failed: slow or filtered cellular data"
      fi

      {
        echo '# HELP cell_backup_check_ok 1 when both the ping and the HTTPS fetch through the cellular tunnel succeeded.'
        echo '# TYPE cell_backup_check_ok gauge'
        echo "cell_backup_check_ok $ok"
        echo '# HELP cell_backup_check_link_ok 1 when the router has carrier on the modem VLAN interface.'
        echo '# TYPE cell_backup_check_link_ok gauge'
        echo "cell_backup_check_link_ok $link_ok"
        echo '# HELP cell_backup_check_modem_ok 1 when the modem answered ARP on its VLAN.'
        echo '# TYPE cell_backup_check_modem_ok gauge'
        echo "cell_backup_check_modem_ok $modem_ok"
        echo '# HELP cell_backup_check_ping_ok 1 when 1.1.1.1 answered a ping through the cellular tunnel.'
        echo '# TYPE cell_backup_check_ping_ok gauge'
        echo "cell_backup_check_ping_ok $ping_ok"
        echo '# HELP cell_backup_check_http_ok 1 when an HTTPS fetch through the cellular tunnel returned 204.'
        echo '# TYPE cell_backup_check_http_ok gauge'
        echo "cell_backup_check_http_ok $http_ok"
        echo '# HELP cell_backup_check_tunnel_rx_packets Packets received through the cellular tunnel between the last two checks.'
        echo '# TYPE cell_backup_check_tunnel_rx_packets gauge'
        echo "cell_backup_check_tunnel_rx_packets $rx_delta"
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
        if [ -n "$rejoin_at" ]; then
          echo '# HELP cell_backup_check_modem_rejoin_timestamp_seconds When the modem last asked for its DHCP lease anew (a reboot or an Ethernet link bounce).'
          echo '# TYPE cell_backup_check_modem_rejoin_timestamp_seconds gauge'
          echo "cell_backup_check_modem_rejoin_timestamp_seconds $rejoin_at"
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

      rejoin_text="never in the last 7 days"
      if [ -n "$rejoin_at" ]; then
        rejoin_text="$(date -d "@$rejoin_at" +'%Y-%m-%d %H:%M') ($rejoin_kind, $(( (now - rejoin_at) / 60 )) min ago)"
      fi
      summary="ok=$ok link=$link_ok modem=$modem_ok ping=$ping_ok rtt=''${rtt:-n/a}s tunnel_rx=$rx_delta http=''${http_code:-none} time=''${http_time:-n/a}s ip=''${public_ip:-unknown}"
      echo "cellular backup: $summary; $reason; modem last re-joined the LAN $rejoin_text"

      previous=$(cat "$last" 2> /dev/null || echo unknown)
      if [ "$ok" != "$previous" ]; then
        echo "$ok" > "$last"
        ${lib.optionalString hasNtfy ''
          if [ "$ok" = 0 ]; then
            ${config.ntfy-alerts.notify} service-failures high "warning,signal_strength" \
              "Cellular backup NOT usable on ${config.networking.hostName}" \
              "Why: $reason. Modem last re-joined the LAN: $rejoin_text. Check: $summary"
          elif [ "$previous" = 0 ]; then
            ${config.ntfy-alerts.notify} service-failures default "white_check_mark,signal_strength" \
              "Cellular backup usable again on ${config.networking.hostName}" \
              "Modem last re-joined the LAN: $rejoin_text. Check: $summary"
          fi
        ''}
      fi
      # The metric is the result; the unit itself always succeeds.
      exit 0
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
    description = "Check the cellular backup uplink every five minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
      Persistent = false;
    };
  };
}

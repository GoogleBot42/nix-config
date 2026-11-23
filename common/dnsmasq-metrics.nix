{ config, lib, pkgs, ... }:

# dnsmasq metrics for the fleet scraper, through node_exporter's textfile
# collector, on any host that runs dnsmasq: the DHCP lease table (one series
# per lease, labelled like dnsmasq_exporter's so dashboards work with either)
# and the DNS cache counters dnsmasq publishes over CHAOS-class TXT queries.
# Riding on node_exporter keeps it to the one scraped port the tailnet ACL
# already opens.

let
  cfg = config.services.dnsmasq;
  textfileDir = config.services.prometheus.exporters.node.textfileDirectory;
  leaseFile = lib.head (cfg.settings.dhcp-leasefile or [ "/var/lib/dnsmasq/dnsmasq.leases" ]);

  probe = pkgs.writeShellScript "dnsmasq-probe" ''
    set -u
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.dnsutils ]}"

    if [ -r "${leaseFile}" ]; then
      awk '
        function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
        NF >= 4 && $1 ~ /^[0-9]+$/ {
          n++
          printf "dnsmasq_lease_expiry{mac_addr=\"%s\",ip_addr=\"%s\",computer_name=\"%s\",client_id=\"%s\"} %s\n",
            esc($2), esc($3), esc($4), esc($5), $1
        }
        END { printf "dnsmasq_leases %d\n", n }
      ' "${leaseFile}"
    fi

    # Counters dnsmasq answers for in the CHAOS class; one value each.
    for stat in cachesize insertions evictions misses hits auth; do
      v=$(dig +short +time=2 +tries=1 @127.0.0.1 chaos txt "$stat.bind" 2>/dev/null | tr -d '"')
      case "$v" in
  ''| * [ !0-9 ] * );
  ;
  *) printf 'dnsmasq_%s %s\n' "$stat" "$v" ;;
  esac
  done
  printf 'dnsmasq_metrics_timestamp_seconds %s\n' "$(date +%s)"
  '';

  writer = pkgs.writeShellScript "dnsmasq-metrics" ''
  set -u
  out = "${textfileDir}/dnsmasq.prom"
    ${probe} > "$out.tmp" && mv "$out.tmp" "$out"
    '' ;
in
{
  config = lib.mkIf (cfg.enable && config.services.prometheus.exporters.node.enable) {
    systemd.services.dnsmasq-metrics = {
      description = "Export dnsmasq metrics for node_exporter";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = writer;
      };
    };
    systemd.timers.dnsmasq-metrics = {
      description = "Refresh dnsmasq metrics";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "30s";
        AccuracySec = "5s";
      };
    };
  };
}


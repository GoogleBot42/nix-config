{ config, lib, pkgs, ... }:

# dnsmasq metrics for the fleet scraper, through node_exporter's textfile
# collector, on any host that runs dnsmasq: the DHCP lease table (one series
# per lease, labelled like dnsmasq_exporter's so dashboards work with either,
# plus the dnsmasq network the address belongs to) and the DNS cache counters
# dnsmasq publishes over CHAOS-class TXT queries. Riding on node_exporter
# keeps it to the one scraped port the tailnet ACL already opens.

let
  cfg = config.services.dnsmasq;
  textfileDir = config.services.prometheus.exporters.node.textfileDirectory;
  leaseFile = lib.head (cfg.settings.dhcp-leasefile or [ "/var/lib/dnsmasq/dnsmasq.leases" ]);

  asList = v: if v == null then [ ] else lib.toList v;
  isIPv4 = s: builtins.match "[0-9]+(\\.[0-9]+){3}" s != null;
  isMac = s: builtins.match "[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f]){5}" s != null;
  # A bare word in a dhcp-host or host-record entry that is neither an
  # address, a MAC, a keyword (id:, set:, tag:) nor a lease time is the name.
  isName = s: !(isIPv4 s) && !(isMac s) && !(lib.hasInfix ":" s)
    && builtins.match "([0-9]+[smhdw]?|infinite|ignore)" s == null;

  # "tag start netmask" per dhcp-range that carries a netmask (the form
  # "set:tag,start,end,netmask[,lease]"); a range without one cannot be
  # matched against lease addresses here and is left out.
  rangeLines = lib.concatMap
    (range:
      let
        parts = lib.splitString "," range;
        ips = builtins.filter isIPv4 parts;
        tags = builtins.filter (lib.hasPrefix "set:") parts;
        name = if tags != [ ] then lib.removePrefix "set:" (lib.head tags) else lib.head ips;
      in
      lib.optional (builtins.length ips >= 3) "${name} ${builtins.elemAt ips 0} ${builtins.elemAt ips 2}")
    (asList (cfg.settings.dhcp-range or [ ]));

  # "mac name" per MAC of a named dhcp-host: dnsmasq leaves the lease itself
  # nameless ("*") when the name is also fixed in the DNS (host-record), which
  # is exactly the case for a host pinned on several networks.
  hostLines = lib.concatMap
    (host:
      let
        parts = lib.splitString "," host;
        names = builtins.filter isName parts;
      in
      lib.optionals (names != [ ])
        (map (mac: "${lib.toLower mac} ${lib.head names}") (builtins.filter isMac parts)))
    (asList (cfg.settings.dhcp-host or [ ]));

  # "ip name" per address of a host-record, the fallback for a nameless lease
  # whose MAC is not pinned.
  recordLines = lib.concatMap
    (record:
      let
        parts = lib.splitString "," record;
        names = builtins.filter isName parts;
      in
      lib.optionals (names != [ ])
        (map (ip: "${ip} ${lib.head names}") (builtins.filter isIPv4 parts)))
    (asList (cfg.settings.host-record or [ ]));

  table = name: lines: pkgs.writeText "dnsmasq-${name}" (lib.concatMapStrings (l: l + "\n") (lib.unique lines));
  rangeTable = table "ranges" rangeLines;
  hostTable = table "hosts" hostLines;
  recordTable = table "records" recordLines;

  probe = pkgs.writeShellScript "dnsmasq-probe" ''
    set -u
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.dnsutils ]}"

    if [ -r "${leaseFile}" ]; then
      awk -v ranges="${rangeTable}" -v hosts="${hostTable}" -v records="${recordTable}" '
        function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
        function ip2n(s, a) { split(s, a, "."); return ((a[1] * 256 + a[2]) * 256 + a[3]) * 256 + a[4] }
        function network(ip, i, n) {
          n = ip2n(ip)
          for (i = 1; i <= nranges; i++)
            if (and(n, rmask[i]) == and(rnet[i], rmask[i])) return rname[i]
          return ""
        }
        BEGIN {
          while ((getline line < ranges) > 0) {
            split(line, f, " "); nranges++
            rname[nranges] = f[1]; rnet[nranges] = ip2n(f[2]); rmask[nranges] = ip2n(f[3])
          }
          while ((getline line < hosts) > 0) { split(line, f, " "); byMac[f[1]] = f[2] }
          while ((getline line < records) > 0) { split(line, f, " "); byIp[f[1]] = f[2] }
        }
        NF >= 4 && $1 ~ /^[0-9]+$/ {
          n++
          name = $4
          if (name == "*") {
            if (tolower($2) in byMac) name = byMac[tolower($2)]
            else if ($3 in byIp) name = byIp[$3]
          }
          printf "dnsmasq_lease_expiry{mac_addr=\"%s\",ip_addr=\"%s\",computer_name=\"%s\",client_id=\"%s\",network=\"%s\"} %s\n",
            esc($2), esc($3), esc(name), esc($5), esc(network($3)), $1
        }
        END { printf "dnsmasq_leases %d\n", n }
      ' "${leaseFile}"
    fi

    # Counters dnsmasq answers for in the CHAOS class; one value each.
    for stat in cachesize insertions evictions misses hits auth; do
      v=$(dig +short +time=2 +tries=1 @127.0.0.1 chaos txt "$stat.bind" 2>/dev/null | tr -d '"')
      case "$v" in
        '''|*[!0-9]*) ;;
        *) printf 'dnsmasq_%s %s\n' "$stat" "$v" ;;
      esac
    done
    printf 'dnsmasq_metrics_timestamp_seconds %s\n' "$(date +%s)"
  '';

  writer = pkgs.writeShellScript "dnsmasq-metrics" ''
    set -u
    out="${textfileDir}/dnsmasq.prom"
    ${probe} > "$out.tmp" && mv "$out.tmp" "$out"
  '';
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

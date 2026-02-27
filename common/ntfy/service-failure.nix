{ config, lib, pkgs, ... }:

let
  cfg = config.ntfy-alerts;
in
{
  config = lib.mkIf config.thisMachine.hasRole."ntfy" {
    systemd.services."ntfy-failure@" = {
      description = "Send ntfy alert for failed unit %i";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/run/agenix/ntfy-token";
        ExecStart = "${pkgs.writeShellScript "ntfy-failure-notify" ''
          unit="$1"
          logfile=$(mktemp)
          trap 'rm -f "$logfile"' EXIT
          ${pkgs.systemd}/bin/journalctl -u "$unit" -n 50 --no-pager -o short > "$logfile" 2>/dev/null \
            || echo "(no logs available)" > "$logfile"
          ${lib.getExe pkgs.curl} \
            -T "$logfile" \
            --fail --silent --show-error \
            --max-time 30 --retry 3 \
            ${cfg.curlExtraArgs} \
            -H "Authorization: Bearer $NTFY_TOKEN" \
            -H "Title: Service failure on ${config.networking.hostName}" \
            -H "Priority: high" \
            -H "Tags: rotating_light" \
            -H "Message: Unit $unit failed at $(date +%c)" \
            -H "Filename: $unit.log" \
            "${cfg.serverUrl}/service-failures"
        ''} %i";
      };
    };

    # Apply OnFailure to all services via a systemd drop-in
    systemd.packages = [
      (pkgs.runCommand "ntfy-on-failure-dropin" { } ''
        mkdir -p $out/lib/systemd/system/service.d
        cat > $out/lib/systemd/system/service.d/ntfy-on-failure.conf <<'EOF'
        [Unit]
        OnFailure=ntfy-failure@%p.service
        EOF
      '')
    ];
  };
}

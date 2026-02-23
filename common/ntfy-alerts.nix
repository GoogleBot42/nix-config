{ config, lib, pkgs, ... }:

let
  cfg = config.ntfy-alerts;
in
{
  options.ntfy-alerts = {
    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://ntfy.neet.dev";
      description = "Base URL of the ntfy server.";
    };

    topic = lib.mkOption {
      type = lib.types.str;
      default = "service-failures";
      description = "ntfy topic to publish alerts to.";
    };
  };

  config = lib.mkIf config.thisMachine.hasRole."ntfy" {
    age.secrets.ntfy-token.file = ../secrets/ntfy-token.age;

    systemd.services."ntfy-failure@" = {
      description = "Send ntfy alert for failed unit %i";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/run/agenix/ntfy-token";
        ExecStart = "${pkgs.writeShellScript "ntfy-failure-notify" ''
          unit="$1"
          ${lib.getExe pkgs.curl} \
            --fail --silent --show-error \
            --max-time 30 --retry 3 \
            -H "Authorization: Bearer $NTFY_TOKEN" \
            -H "Title: Service failure on ${config.networking.hostName}" \
            -H "Priority: high" \
            -H "Tags: rotating_light" \
            -d "Unit $unit failed at $(date +%c)" \
            "${cfg.serverUrl}/${cfg.topic}"
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

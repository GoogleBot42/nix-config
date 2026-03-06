{ config, lib, pkgs, ... }:

let
  cfg = config.ntfy-alerts;
  hasNtfy = config.thisMachine.hasRole."ntfy";

  checkScript = pkgs.writeShellScript "dimm-temp-check" ''
    PATH="${lib.makeBinPath [ pkgs.lm_sensors pkgs.gawk pkgs.coreutils pkgs.curl ]}"

    threshold=55
    hot=""
    summary=""

    while IFS= read -r line; do
      case "$line" in
        spd5118-*)
          chip="$line"
          ;;
        *temp1_input:*)
          temp="''${line##*: }"
          whole="''${temp%%.*}"
          summary="''${summary:+$summary, }$chip: ''${temp}°C"
          if [ "$whole" -ge "$threshold" ]; then
            hot="$hot"$'\n'"  $chip: ''${temp}°C"
          fi
          ;;
      esac
    done < <(sensors -u 'spd5118-*' 2>/dev/null)

    echo "$summary"

    if [ -n "$hot" ]; then
      message="DIMM temperature above ''${threshold}°C on ${config.networking.hostName}:$hot"

      curl \
        --fail --silent --show-error \
        --max-time 30 --retry 3 \
        -H "Authorization: Bearer $NTFY_TOKEN" \
        -H "Title: High DIMM temperature on ${config.networking.hostName}" \
        -H "Priority: high" \
        -H "Tags: thermometer" \
        -d "$message" \
        "${cfg.serverUrl}/service-failures"

      echo "$message" >&2
    fi
  '';
in
{
  options.ntfy-alerts.dimmTempCheck.enable = lib.mkEnableOption "DDR5 DIMM temperature monitoring via spd5118";

  config = lib.mkIf (cfg.dimmTempCheck.enable && hasNtfy) {
    systemd.services.dimm-temp-check = {
      description = "Check DDR5 DIMM temperatures and alert on overheating";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/run/agenix/ntfy-token";
        ExecStart = checkScript;
      };
    };

    systemd.timers.dimm-temp-check = {
      description = "Periodic DDR5 DIMM temperature check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };
  };
}

{ config, lib, pkgs, ... }:

let
  cfg = config.ntfy-alerts;
  hasNtfy = config.thisMachine.hasRole."ntfy";
  host = config.networking.hostName;

  checkScript = pkgs.writeShellScript "edac-check" ''
    PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.curl ]}"

    state="$STATE_DIRECTORY/counts"
    edac=/sys/devices/system/edac/mc

    notify() { # priority tags title message
      curl \
        --fail --silent --show-error \
        --max-time 30 --retry 3 \
        -H "Authorization: Bearer $NTFY_TOKEN" \
        -H "Title: $3" \
        -H "Priority: $1" \
        -H "Tags: $2" \
        -d "$4" \
        "${cfg.serverUrl}/service-failures"
      echo "$4" >&2
    }

    # State is one "mcN ce ue" line per controller, or the word "absent".
    declare -A prev_ce prev_ue
    was_absent=0
    if [ -r "$state" ]; then
      while read -r mc ce ue; do
        if [ "$mc" = absent ]; then
          was_absent=1
          continue
        fi
        prev_ce[$mc]=$ce
        prev_ue[$mc]=$ue
      done < "$state"
    fi

    controllers=$(ls -d "$edac"/mc[0-9]* 2>/dev/null || true)

    if [ -z "$controllers" ]; then
      echo absent > "$state"
      if [ "$was_absent" = 0 ]; then
        notify high warning "ECC reporting absent on ${host}" \
          "No EDAC memory controller is registered on ${host}: ECC is off in firmware or the EDAC driver did not bind, so memory errors are not being counted."
      fi
      exit 0
    fi

    new_ce=0
    new_ue=0
    summary=""
    details=""
    : > "$state.new"
    for dir in $controllers; do
      mc=$(basename "$dir")
      ce=$(cat "$dir/ce_count")
      ue=$(cat "$dir/ue_count")
      echo "$mc $ce $ue" >> "$state.new"

      p_ce=''${prev_ce[$mc]:-0}
      p_ue=''${prev_ue[$mc]:-0}
      # Counters restart from zero at boot; a drop means the baseline is gone.
      [ "$ce" -lt "$p_ce" ] && p_ce=0
      [ "$ue" -lt "$p_ue" ] && p_ue=0
      new_ce=$((new_ce + ce - p_ce))
      new_ue=$((new_ue + ue - p_ue))

      summary="''${summary:+$summary, }$mc: $ce corrected, $ue uncorrected"
      for dimm in "$dir"/dimm[0-9]*; do
        [ -d "$dimm" ] || continue
        d_ce=$(cat "$dimm/dimm_ce_count")
        d_ue=$(cat "$dimm/dimm_ue_count")
        if [ "$d_ce" -gt 0 ] || [ "$d_ue" -gt 0 ]; then
          details="$details"$'\n'"  $(cat "$dimm/dimm_label"): $d_ce corrected, $d_ue uncorrected"
        fi
      done
    done
    mv "$state.new" "$state"

    echo "$summary"

    if [ "$new_ue" -gt 0 ]; then
      notify urgent rotating_light "Uncorrectable memory error on ${host}" \
        "$new_ue new uncorrectable and $new_ce new corrected ECC errors on ${host} since the last check. Totals since boot: $summary$details"
    elif [ "$new_ce" -gt 0 ]; then
      notify high warning "Corrected memory errors on ${host}" \
        "$new_ce new corrected ECC errors on ${host} since the last check. Totals since boot: $summary$details"
    fi
  '';
in
{
  options.ntfy-alerts.edacCheck.enable = lib.mkEnableOption "ECC memory error monitoring via EDAC";

  config = lib.mkIf (cfg.edacCheck.enable && hasNtfy) {
    systemd.services.edac-check = {
      description = "Check EDAC memory error counters and alert on new errors";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = "/run/agenix/ntfy-token";
        StateDirectory = "edac-check";
        ExecStart = checkScript;
      };
    };

    systemd.timers.edac-check = {
      description = "Periodic EDAC memory error check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Persistent = true;
      };
    };
  };
}

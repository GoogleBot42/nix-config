{ config, lib, pkgs, ... }:

# Announces the moment the cellular modem re-joins the LAN. The modem asks
# dnsmasq for its lease anew in exactly two situations: after a boot (its
# rootfs is RAM-only, so the discover carries no address) and after its
# Ethernet link went down and up (netifd restarts the client, which asks for
# its old address). Both are invisible to the five-minute end-to-end check
# when the tunnel is back within a couple of minutes, and both are the events
# that explain a flaky backup. The dnsmasq journal is followed live; the
# cell network's DHCP pool holds the modem's address only, so every discover
# on that interface is the modem.

let
  lan = "br-cell";
  hasNtfy = config.thisMachine.hasRole."ntfy";

  events = pkgs.writeShellApplication {
    name = "cell-modem-events";
    runtimeInputs = with pkgs; [ coreutils systemd ];
    text = ''
      # When the previous re-join happened, kept across restarts.
      last_file=$STATE_DIRECTORY/last-rejoin
      last=$(cat "$last_file" 2> /dev/null || echo 0)

      handle() {
        local rest=$1 now kind detail since
        now=$(date +%s)
        if [[ "$rest" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\  ]]; then
          kind="link bounce"
          detail="its Ethernet link went down and came back up (it asked for its old address)"
        else
          kind="reboot"
          detail="it booted (it asked for a lease with no address)"
        fi
        # The modem retransmits a discover within seconds; one event, one message.
        if [ $((now - last)) -lt 60 ]; then
          echo "modem re-join ($kind) within 60 s of the previous one, not announced again"
          last=$now; echo "$last" > "$last_file"
          return
        fi
        since=""
        [ "$last" -gt 0 ] && since=", previous re-join $(( (now - last) / 60 )) min earlier"
        last=$now; echo "$last" > "$last_file"
        echo "cellular modem re-joined the LAN: $kind$since"
        ${lib.optionalString hasNtfy ''
          ${config.ntfy-alerts.notify} service-failures default "arrows_counterclockwise,signal_strength" \
            "Cellular modem re-joined the LAN on ${config.networking.hostName}" \
            "At $(date -d "@$now" +%H:%M:%S) the modem asked for its DHCP lease anew: $detail$since."
        ''}
      }

      # `cell-modem-events -` reads journal lines from stdin, for testing.
      if [ "''${1:-}" = - ]; then
        source=(cat)
      else
        source=(journalctl -f -n 0 -o cat -u dnsmasq.service)
      fi
      "''${source[@]}" | while IFS= read -r line; do
        case "$line" in
          "DHCPDISCOVER(${lan}) "*) handle "''${line#DHCPDISCOVER(${lan}) }" ;;
        esac
      done
    '';
  };
in
{
  systemd.services.cell-modem-events = {
    description = "Announce the cellular modem re-joining the LAN";
    wantedBy = [ "multi-user.target" ];
    after = [ "dnsmasq.service" ];
    serviceConfig = {
      ExecStart = lib.getExe events;
      Restart = "always";
      RestartSec = 5;
      StateDirectory = "cell-modem-events";
    } // lib.optionalAttrs hasNtfy {
      EnvironmentFile = "/run/agenix/ntfy-token";
    };
  };
}

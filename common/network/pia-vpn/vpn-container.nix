{ config, lib, allModules, ... }:

# VPN container: runs all PIA logic, acts as WireGuard gateway + NAT for service containers.

with lib;

let
  cfg = config.pia-vpn;
  hostName = config.networking.hostName;
  scripts = import ./scripts.nix;

  # Port forwarding derived state
  forwardingContainers = filterAttrs (_: c: c.receiveForwardedPort != null) cfg.containers;
  portForwarding = forwardingContainers != { };
  forwardingContainerName = if portForwarding then head (attrNames forwardingContainers) else null;
  forwardingContainer = if portForwarding then forwardingContainers.${forwardingContainerName} else null;

  serverFile = "/var/lib/pia-vpn/server.json";
  wgFile = "/var/lib/pia-vpn/wg.conf";
  portRenewalFile = "/var/lib/pia-vpn/port-renewal.json";
  proxy = "http://${cfg.hostAddress}:${toString cfg.proxyPort}";

  # DNAT/forwarding rules for port forwarding
  dnatSetupScript = optionalString portForwarding (
    let
      fwd = forwardingContainer.receiveForwardedPort;
      targetIp = forwardingContainer.ip;
      dnatTarget = if fwd.port != null then "${targetIp}:${toString fwd.port}" else targetIp;
      targetPort = if fwd.port != null then toString fwd.port else "$PORT";
      tcpRules = optionalString (fwd.protocol == "tcp" || fwd.protocol == "both") ''
        echo "Setting up TCP DNAT: port $PORT → ${targetIp}:${targetPort}"
        iptables -t nat -A PREROUTING -i ${cfg.interfaceName} -p tcp --dport $PORT -j DNAT --to ${dnatTarget}
        iptables -A FORWARD -i ${cfg.interfaceName} -d ${targetIp} -p tcp --dport ${targetPort} -j ACCEPT
      '';
      udpRules = optionalString (fwd.protocol == "udp" || fwd.protocol == "both") ''
        echo "Setting up UDP DNAT: port $PORT → ${targetIp}:${targetPort}"
        iptables -t nat -A PREROUTING -i ${cfg.interfaceName} -p udp --dport $PORT -j DNAT --to ${dnatTarget}
        iptables -A FORWARD -i ${cfg.interfaceName} -d ${targetIp} -p udp --dport ${targetPort} -j ACCEPT
      '';
      onPortForwarded = optionalString (forwardingContainer.onPortForwarded != null) ''
        TARGET_IP="${targetIp}"
        export PORT TARGET_IP
        echo "Running onPortForwarded hook for ${forwardingContainerName} (port=$PORT, target=$TARGET_IP)"
        ${forwardingContainer.onPortForwarded}
      '';
    in
    ''
      if [ "$PORT" -lt 10000 ]; then
        echo "ERROR: PIA assigned low port $PORT (< 10000), refusing to set up DNAT" >&2
      else
        ${tcpRules}
        ${udpRules}
        ${onPortForwarded}
      fi
    ''
  );
in
{
  config = mkIf cfg.enable {
    # Give the container more time to boot (pia-vpn-setup retries can delay readiness)
    systemd.services."container@pia-vpn".serviceConfig.TimeoutStartSec = mkForce "180s";

    containers.pia-vpn = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      hostBridge = cfg.bridgeName;
      interfaces = [ cfg.interfaceName ];

      bindMounts."/run/agenix" = {
        hostPath = "/run/agenix";
        isReadOnly = true;
      };

      config = { config, pkgs, lib, ... }:
        let
          scriptPkgs = with pkgs; [ wireguard-tools iproute2 curl jq iptables coreutils openssl ];
        in
        {
          imports = allModules;

          networking.hosts = cfg.containerHosts;

          # Static IP on bridge — no gateway (VPN container routes via WG only)
          networking.useNetworkd = true;
          systemd.network.enable = true;
          networking.useDHCP = false;

          systemd.network.networks."20-eth0" = {
            matchConfig.Name = "eth0";
            networkConfig = {
              Address = "${cfg.vpnAddress}/${cfg.subnetPrefixLen}";
              DHCPServer = false;
            };
          };

          # Ignore WG interface for wait-online (it's configured manually, not by networkd)
          systemd.network.wait-online.ignoredInterfaces = [ cfg.interfaceName ];

          # Route ntfy alerts through the host proxy (VPN container has no gateway on eth0)
          ntfy-alerts.curlExtraArgs = "--proxy http://${cfg.hostAddress}:${toString cfg.proxyPort}";
          ntfy-alerts.ignoredUnits = [ "logrotate" ];
          ntfy-alerts.hostLabel = "${hostName}/pia-vpn";

          # Enable forwarding so bridge traffic can go through WG
          boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

          # Trust bridge interface
          networking.firewall.trustedInterfaces = [ "eth0" ];

          # DNS: use systemd-resolved listening on bridge IP so service containers
          # can use VPN container as DNS server (queries go through WG tunnel = no DNS leak)
          services.resolved = {
            enable = true;
            settings.Resolve.DNSStubListenerExtra = cfg.vpnAddress;
          };

          # Don't use host resolv.conf — resolved manages DNS
          networking.useHostResolvConf = false;

          # State directory for PIA config files
          systemd.tmpfiles.rules = [
            "d /var/lib/pia-vpn 0700 root root -"
          ];

          # PIA VPN setup service — does all the PIA auth, WG config, and NAT setup
          systemd.services.pia-vpn-setup = {
            description = "PIA VPN WireGuard Setup";

            wants = [ "network-online.target" ];
            after = [ "network.target" "network-online.target" "systemd-networkd.service" ];
            wantedBy = [ "multi-user.target" ];

            path = scriptPkgs;

            serviceConfig = {
              Type = "simple";
              Restart = "always";
              RestartSec = "5m";
              RuntimeMaxSec = "30d";
            };

            script = ''
              set -euo pipefail
              ${scripts.scriptCommon}

              trap 'cleanupVpn ${cfg.interfaceName}' EXIT
              cleanupVpn ${cfg.interfaceName}

              proxy="${proxy}"

              # 1. Authenticate with PIA via proxy (VPN container has no internet yet)
              echo "Choosing PIA server in region '${cfg.serverLocation}'..."
              choosePIAServer '${cfg.serverLocation}'

              echo "Fetching PIA authentication token..."
              fetchPIAToken

              # 2. Generate WG keys and authorize with PIA server
              echo "Generating WireGuard keypair..."
              generateWireguardKey

              echo "Authorizing key with PIA server $WG_HOSTNAME..."
              authorizeKeyWithPIAServer

              # 3. Configure WG interface (already created by host and moved into our namespace)
              echo "Configuring WireGuard interface ${cfg.interfaceName}..."
              writeWireguardQuickFile '${wgFile}' ${toString cfg.wireguardListenPort}
              writeChosenServerToFile '${serverFile}'
              connectToServer '${wgFile}' '${cfg.interfaceName}'

              # 4. Default route through WG
              ip route replace default dev ${cfg.interfaceName}
              echo "Default route set through ${cfg.interfaceName}"

              # 5. NAT: masquerade bridge → WG (so service containers' traffic appears to come from VPN IP)
              echo "Setting up NAT masquerade..."
              iptables -t nat -A POSTROUTING -o ${cfg.interfaceName} -j MASQUERADE
              iptables -A FORWARD -i eth0 -o ${cfg.interfaceName} -j ACCEPT
              iptables -A FORWARD -i ${cfg.interfaceName} -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

              ${optionalString portForwarding ''
                # 6. Port forwarding setup
                echo "Reserving port forward..."
                reservePortForward
                writePortRenewalFile '${portRenewalFile}'

                # First bindPort triggers actual port allocation
                echo "Binding port $PORT..."
                refreshPIAPort

                echo "PIA assigned port: $PORT"

                # DNAT rules to forward PIA port to target container
                ${dnatSetupScript}
              ''}

              echo "PIA VPN setup complete"
              exec sleep infinity
            '';

          };

          # Port refresh timer (every 10 min) — keeps PIA port forwarding alive
          systemd.services.pia-vpn-port-refresh = mkIf portForwarding {
            description = "PIA VPN Port Forward Refresh";
            after = [ "pia-vpn-setup.service" ];
            requires = [ "pia-vpn-setup.service" ];

            path = scriptPkgs;

            serviceConfig.Type = "oneshot";

            script = ''
              set -euo pipefail
              ${scripts.scriptCommon}
              loadChosenServerFromFile '${serverFile}'
              readPortRenewalFile '${portRenewalFile}'
              echo "Refreshing PIA port forward..."
              refreshPIAPort
            '';
          };

          systemd.timers.pia-vpn-port-refresh = mkIf portForwarding {
            partOf = [ "pia-vpn-port-refresh.service" ];
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*:0/10";
              RandomizedDelaySec = "1m";
            };
          };

          # Periodic VPN connectivity check — fails if VPN or internet is down,
          # triggering ntfy alert via the OnFailure drop-in.
          # Tracks failures with a counter file so only the first 3 failures per
          # day trigger an alert (subsequent failures exit 0 to suppress noise).
          systemd.services.pia-vpn-check = {
            description = "Check PIA VPN connectivity";
            after = [ "pia-vpn-setup.service" ];
            requires = [ "pia-vpn-setup.service" ];

            path = with pkgs; [ wireguard-tools iputils coreutils gawk jq ];

            serviceConfig.Type = "oneshot";

            script = ''
              set -euo pipefail

              COUNTER_FILE="/var/lib/pia-vpn/check-fail-count.json"
              MAX_ALERTS=3

              check_vpn() {
                # Check that WireGuard has a peer with a recent handshake (within 3 minutes)
                handshake=$(wg show ${cfg.interfaceName} latest-handshakes | awk '{print $2}')
                if [ -z "$handshake" ] || [ "$handshake" -eq 0 ]; then
                  echo "No WireGuard handshake recorded" >&2
                  return 1
                fi
                now=$(date +%s)
                age=$((now - handshake))
                if [ "$age" -gt 180 ]; then
                  echo "WireGuard handshake is stale (''${age}s ago)" >&2
                  return 1
                fi

                # Verify internet connectivity through VPN tunnel
                if ! ping -c1 -W10 1.1.1.1 >/dev/null 2>&1; then
                  echo "Cannot reach internet through VPN" >&2
                  return 1
                fi

                echo "PIA VPN connectivity OK (handshake ''${age}s ago)"
                return 0
              }

              MAX_RETRIES=4
              for attempt in $(seq 1 $MAX_RETRIES); do
                if check_vpn; then
                  rm -f "$COUNTER_FILE"
                  exit 0
                fi
                if [ "$attempt" -lt "$MAX_RETRIES" ]; then
                  echo "Attempt $attempt/$MAX_RETRIES failed, retrying in 5 minutes..." >&2
                  sleep 300
                fi
              done

              # Failed — read and update counter (reset if from a previous day)
              today=$(date +%Y-%m-%d)
              count=0
              if [ -f "$COUNTER_FILE" ]; then
                stored=$(jq -r '.date // ""' "$COUNTER_FILE")
                if [ "$stored" = "$today" ]; then
                  count=$(jq -r '.count // 0' "$COUNTER_FILE")
                fi
              fi
              count=$((count + 1))
              jq -n --arg date "$today" --argjson count "$count" \
                '{"date": $date, "count": $count}' > "$COUNTER_FILE"

              if [ "$count" -le "$MAX_ALERTS" ]; then
                echo "Failure $count/$MAX_ALERTS today — alerting" >&2
                exit 1
              else
                echo "Failure $count today — suppressing alert (already sent $MAX_ALERTS)" >&2
                exit 0
              fi
            '';
          };

          systemd.timers.pia-vpn-check = {
            description = "Periodic PIA VPN connectivity check";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*:0/30";
              RandomizedDelaySec = "30s";
            };
          };
        };
    };
  };
}

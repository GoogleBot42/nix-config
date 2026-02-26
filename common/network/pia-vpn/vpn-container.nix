{ config, lib, allModules, ... }:

# VPN container: runs all PIA logic, acts as WireGuard gateway + NAT for service containers.

with lib;

let
  cfg = config.pia-vpn;
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
          scriptPkgs = with pkgs; [ wireguard-tools iproute2 curl jq iptables coreutils ];
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
              RestartSec = "10s";
              RuntimeMaxSec = "30d";
            };

            script = ''
              set -euo pipefail
              ${scripts.scriptCommon}

              # Clean up stale state from previous attempts
              wg set ${cfg.interfaceName} listen-port 0 2>/dev/null || true
              ip -4 address flush dev ${cfg.interfaceName} 2>/dev/null || true
              ip route del default dev ${cfg.interfaceName} 2>/dev/null || true
              iptables -t nat -F 2>/dev/null || true
              iptables -F FORWARD 2>/dev/null || true

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

            preStop = ''
              echo "Tearing down PIA VPN..."
              ip -4 address flush dev ${cfg.interfaceName} 2>/dev/null || true
              ip route del default dev ${cfg.interfaceName} 2>/dev/null || true
              iptables -t nat -F POSTROUTING 2>/dev/null || true
              iptables -F FORWARD 2>/dev/null || true
              ${optionalString portForwarding ''
                iptables -t nat -F PREROUTING 2>/dev/null || true
              ''}
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
        };
    };
  };
}

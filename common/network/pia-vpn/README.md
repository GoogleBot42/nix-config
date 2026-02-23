# PIA VPN Multi-Container Module

Routes service containers through a PIA WireGuard VPN using a shared bridge network.

## Architecture

```
                  internet
                     │
              ┌──────┴──────┐
              │    Host      │
              │  tinyproxy   │  ← PIA API bootstrap proxy
              │  10.100.0.1  │
              └──────┬───────┘
                     │ br-vpn (no IPMasquerade)
        ┌────────────┼──────────────┐
        │            │              │
 ┌──────┴──────┐ ┌───┴────┐  ┌─────┴──────┐
 │ VPN ctr     │ │ servarr│  │transmission│
 │ 10.100.0.2  │ │  .11   │  │   .10      │
 │ piaw (WG)   │ │        │  │            │
 │ gateway+NAT │ └────────┘  └────────────┘
 └─────────────┘
```

- **Host** creates the WG interface (encrypted UDP stays in host netns) and runs tinyproxy on the bridge so the VPN container can bootstrap PIA auth before WG is up.
- **VPN container** authenticates with PIA via the proxy, configures WG, sets up NAT (masquerade bridge→WG) and optional port forwarding DNAT.
- **Service containers** default-route through the VPN container. No WG interface = no internet if VPN is down = leak-proof by topology.
- **Host** reaches containers directly on the bridge for nginx reverse proxying.

## Key design decisions

- **Bridge, not veth pairs**: All containers share one bridge (`br-vpn`), so the VPN container can act as a single gateway. The host does NOT masquerade bridge traffic — only the VPN container does (through WG).
- **Port forwarding is implicit**: If any container sets `receiveForwardedPort`, the VPN container automatically handles PIA port forwarding and DNAT. No separate toggle needed.
- **DNS through WG**: Service containers use the VPN container as their DNS server. The VPN container runs `systemd-resolved` listening on its bridge IP, forwarding queries through the WG tunnel.
- **Monthly renewal**: `pia-vpn-setup` uses `Type=simple` + `Restart=always` + `RuntimeMaxSec=30d` to periodically re-authenticate with PIA and get a fresh port forwarding signature (signatures expire after ~2 months). Service containers are unaffected during renewal.

## Files

| File | Purpose |
|---|---|
| `default.nix` | Options, bridge, tinyproxy, host firewall, WG interface creation, assertions |
| `vpn-container.nix` | VPN container: PIA auth, WG config, NAT, DNAT, port refresh timer |
| `service-container.nix` | Generates service containers with static IP and gateway→VPN |
| `scripts.nix` | Bash function library for PIA API calls and WG configuration |
| `ca.rsa.4096.crt` | PIA CA certificate for API TLS verification |

## Usage

```nix
pia-vpn = {
  enable = true;
  serverLocation = "swiss";

  containers.my-service = {
    ip = "10.100.0.10";
    mounts."/data".hostPath = "/data";
    config = { services.my-app.enable = true; };

    # Optional: receive PIA's forwarded port (at most one container)
    receiveForwardedPort = { port = 8080; protocol = "both"; };
    onPortForwarded = ''
      echo "PIA assigned port $PORT, forwarding to $TARGET_IP:8080"
    '';
  };
};
```

## Debugging

```bash
# Check VPN container status
machinectl shell pia-vpn
systemctl status pia-vpn-setup
journalctl -u pia-vpn-setup

# Verify WG tunnel
wg show

# Check NAT/DNAT rules
iptables -t nat -L -v
iptables -L FORWARD -v

# From a service container — verify VPN routing
curl ifconfig.me

# Port refresh logs
journalctl -u pia-vpn-port-refresh
```

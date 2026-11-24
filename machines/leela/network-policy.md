# Leela network policy

`machines/leela/networking.nix` configures the Mono Gateway Development Kit as
the edge router for three local networks plus one WAN uplink and a cellular
backup uplink. The policy was cross-checked against the OpenWrt APU2 backup
from 2026-07-21; the cellular backup ([CELL-BACKUP.md](./CELL-BACKUP.md)),
the admin VLAN and the PIA VLAN are the additions to it.

## Interfaces and networks

| Role | Interface | Network | Address on router | DHCP pool | Notes |
| --- | --- | --- | --- | --- | --- |
| WAN | `wan` | ISP/uplink | DHCP/RA from provider | n/a | One SFP+ port. Interface names must be confirmed on the serial console before cutover. |
| Main LAN | `br-main` | `192.168.1.1/21` | `192.168.1.1` | `192.168.0.100`-`192.168.0.249` | Native/untagged on the three RJ-45 access ports and VLAN 5 on the SFP+ trunk. IPv4-only until `mainLanIpv6` is switched on. |
| IoT | `vlan-iot` | `192.168.8.1/22` | `192.168.8.1` | `192.168.8.100`-`192.168.8.249` | VLAN 2 on the SFP+ trunk. IPv4-only. |
| Management | `vlan-management` | `192.168.13.1/24` | `192.168.13.1` | `192.168.13.100`-`192.168.13.249` | VLAN 4 on the SFP+ trunk. IPv4-only. |
| Cell | `vlan-cell` | `192.168.14.1/24` | `192.168.14.1` | `192.168.14.2` only | VLAN 14 on the trunk. Home of the UniFi 5G Backup modem; one DHCP address so the GRE endpoint is fixed. IPv4-only. |
| Admin | `vlan-admin` | `192.168.15.1/24` | `192.168.15.1` | `192.168.15.100`-`192.168.15.249` | VLAN 15 on the trunk; the Infosphere SSID. May open connections to every other VLAN by address. IPv4-only. |
| PIA | `vlan-pia` | `192.168.16.1/24` | none (`192.168.16.1` is the VPN container) | `192.168.16.100`-`192.168.16.249` | VLAN 16 on the trunk; the Panama Wormhole SSID. Not an interface of the router: it lives inside the PIA VPN container, which is its only gateway. Everything goes through the PIA tunnel; nothing reaches the LANs. IPv4-only. |
| VPN bridge | `br-vpn` | `10.100.0.1/24` | `10.100.0.1` | n/a | Host side of the PIA VPN container (`10.100.0.2`). Never forwarded. |
| Cell tunnel | `gre-cell` | `100.127.125.128/31` | `100.127.125.129` | n/a | GRE to the modem (`192.168.14.1` ↔ `192.168.14.2`), MTU 1400. Carries the default route only while failed over. |

`trunk` is the tagged LAN trunk; `lan1`, `lan2` and `lan3` are the untagged
main-LAN access ports. Each name is pinned to a physical port by MAC in
`networking.nix`; the kernel `eth*` names are only a bench-time fallback.

## Router-local access

The nftables `input` chain is default-deny.

Allowed to the router:

- Loopback and established/related return traffic.
- `tailscale0` — backup admin path; access control is handled by Tailscale ACLs.
  (The stock NixOS firewall and its `trustedInterfaces` handling are disabled
  on this machine, so this is granted explicitly.)
- On the bench only (`bench = true` in `networking.nix`): SSH from the live
  LAN `192.168.0.0/21` arriving on WAN, because that is the only path to the
  router while it sits behind the old gateway. An assertion keeps this rule
  out of the live build.
- Traffic arriving from the local LAN interfaces (`br-main`, `vlan-iot`,
  `vlan-management` and `vlan-admin`) after the explicit DNS rejects below.
  This permits DHCP, SSH/admin access, and local diagnostics from those
  networks.
- From `vlan-cell`: DHCP, DNS, ICMP, and GRE from the modem's fixed address.
  The modem is a vendor appliance and gets nothing else (no SSH, no metrics).
- From `gre-cell`: ICMP echo and the error types PMTU needs. The router is a
  NAT client inside the tunnel, so nothing initiates towards it.
- From `br-vpn`: TCP 8888 (tinyproxy) from the VPN container's address only,
  which is how the container reaches PIA's API before its tunnel exists.
- WAN DHCPv4 replies to the router's DHCP client.
- WAN DHCPv6 client traffic.
- WAN ping: ICMPv4 echo-request and ICMPv6 echo-request/echo-reply (rate
  limited for ICMPv6), matching OpenWrt's `Allow-Ping`/`Allow-ICMPv6-Input`.
- WAN IGMP, matching OpenWrt's `Allow-IGMP`.
- WAN ICMP/ICMPv6 control/error traffic required for path MTU discovery,
  neighbor/router discovery, and IPv6 control-plane operation.

Blocked to the router:

- Invalid connection-tracking state.
- New WAN connections to router services. There is no WAN SSH, DNS, web, or
  other service exposure.
- DNS queries from IoT and management VLANs to the router (`tcp/53` and
  `udp/53` are rejected before the general LAN accept rule). These devices are
  untrusted; they are also not offered a resolver via DHCP, and the reject
  ensures they cannot use the router for DNS-based exfiltration even if they
  try anyway.
- The PIA bootstrap proxy (`tcp/8888` on the bridge address) from every LAN
  VLAN, rejected before the general LAN accept rule. The bridge address is a
  router-local address like any other, and the proxy exists for the VPN
  container alone; tinyproxy's own allow list is the second line.

## Forwarding

The nftables `forward` chain is default-deny. TCP MSS is clamped to path MTU
in both directions on both WAN interfaces (OpenWrt `mtu_fix`; on the tunnel
this is what keeps TCP working at MTU 1400).

Allowed forwarding:

- Established/related return traffic.
- New traffic from `br-main` or `vlan-admin` to either WAN interface (`wan`
  or `gre-cell`). Which one carries it is a routing decision made by the
  failover watchdog, not a firewall one.
- New traffic from `vlan-admin` to any other VLAN (`br-main`, `vlan-iot`,
  `vlan-management`, `vlan-cell`). Only replies come back; nothing on those
  VLANs can initiate towards the admin VLAN, and broadcast or discovery
  traffic (mDNS, SSDP, Wake-on-LAN) does not cross.
- The modem (`192.168.14.2`) to the cable WAN, for its own eSIM, UniFi
  Mobility and firmware traffic.
- The modem to the UniFi controller on s0: TCP 8080 (inform) and 6789
  (speed test), UDP 3478 (STUN), to `192.168.1.2` on the main LAN and to the
  management VLAN (s0 holds a dynamic lease there).
- `br-main` to `vlan-cell`, so the trusted LAN can reach the modem.
- WAN ICMPv6 echo and control/error forwarding needed for PMTU/NDP behavior
  (rate limited), matching OpenWrt's `Allow-ICMPv6-Forward`.

Blocked forwarding:

- Anything entering or leaving `br-vpn`, stated before every accept rule.
  The PIA VLAN never appears in this chain at all: its interface is inside
  the VPN container (see below).
- New IoT-to-WAN and management-to-WAN traffic.
- IoT-to-main, IoT-to-management, management-to-main, and management-to-IoT
  traffic unless a future explicit rule is added.
- All other new WAN-to-LAN traffic.

The OpenWrt config also carried `Allow-IPSec-ESP` and `Allow-ISAKMP` WAN→LAN
forward rules. They were dropped here: without any DNAT/port-forward those
rules could never match (inbound WAN traffic is addressed to the router
itself), and outbound-initiated IPsec from the LAN already works through
conntrack. Add an explicit DNAT if inbound IPsec to a specific host is ever
needed.

## PIA VLAN

Clients on VLAN 16 reach the Internet only through the PIA WireGuard tunnel,
and reach nothing else. The leak protection is the topology of the
`pia-vpn` module (`common/network/pia-vpn`), not a firewall rule here:

- The VLAN interface `vlan-pia` is created on the trunk by the VPN
  container's unit and moved into the container by nspawn. The router has no
  address on it and no route to it, so no host rule can send its traffic out
  `wan` or `gre-cell`.
- Inside the container, `192.168.16.1` is the DHCP server (networkd,
  `.100`-`.249`, MTU 1420 announced), the resolver (systemd-resolved's stub,
  forwarding to PIA's resolvers through the tunnel) and the only gateway.
  The container's default route is the tunnel; its bridge side has no gateway
  at all. Forwarding from `vlan-pia` is accepted to the tunnel and dropped
  otherwise, so the VLAN cannot reach the bridge (the host's proxy, any
  service container) either.
- The container itself answers the VLAN for DHCP, DNS and ping only. It runs
  no sshd and no mosh (it is administered with `nixos-container root-login`),
  so a VLAN client finds no service to attack on its gateway.
- The tunnel's encrypted UDP leaves from the router's own namespace (the
  WireGuard interface is created on the host and moved into the container)
  and follows the router's default route, so it fails over to the cellular
  backup with everything else.
- With the tunnel down the VLAN has no connectivity at all, by design.
- IPv4-only: the container's VLAN side has no link-local address and
  announces no router, so no client can route IPv6 around the tunnel.

Consequences: `.lan` names do not resolve on this VLAN, the LANs are not
reachable from it, and its leases are not in the DHCP leases dashboard
(they are networkd's, inside the ephemeral container, and start over with
it). The exit country is the module's default (`swiss`).

## IPv6

The WAN interface runs a DHCPv6 client (solicited even without RA M/O flags,
like OpenWrt's `wan6`) and requests a delegated prefix, so the router itself
has global IPv6 connectivity. Announcing the delegated prefix on `br-main`
(SLAAC, dnsmasq as RDNSS, routed rather than NATed, same default-deny forward
policy) is implemented behind `mainLanIpv6` in `networking.nix` and kept off
for the gateway swap; the OpenWrt router never announced a prefix either. IoT
and management have IPv6 disabled entirely (no link-local, no RA): they have
no WAN egress, so global addresses would only widen their local attack
surface. The PIA VLAN has none either (the tunnel carries only IPv4).

## NAT

The IPv4 NAT table masquerades only packets leaving through `wan` or
`gre-cell` whose source is in `internetCidrs`: the main LAN, the admin VLAN
and the cell VLAN (for the modem's own egress). Inside the tunnel the modem NATs again to the
carrier address, so the backup path is double NAT behind CGNAT.

## Failover

`wan-failover.nix` runs a watchdog that pings public resolvers out of `wan`
every 2 s. After three silent rounds, if the tunnel answers a probe at that
moment, it adds a default route through `gre-cell` to the main table at
metric 512 (the WAN lease's is 1024) and flushes the masqueraded conntrack
entries; after fifteen answered rounds it removes the route again. The
switch is a main-table route rather than a policy rule because Tailscale's
fwmark rules pin its own packets to the main table. Table 100 holds a
standing default through the tunnel reached only by packets bound to
`gre-cell` (rule 5300, below Tailscale's 5210-5270), which is how the backup
is probed while idle. State is exported as `wan_failover_active` and
`wan_probe_ok{interface}` through node_exporter and announced on ntfy.

## DNS

dnsmasq serves the LAN interfaces only (`local-service`, `except-interface`
WAN, DNS rebind protection on). Upstream resolvers are explicit (`1.1.1.1`,
`8.8.8.8`) via `no-resolv`: systemd-resolved is disabled on this machine, so
DHCP-learned ISP resolvers are deliberately not used. Main-LAN clients receive
the router as their resolver over DHCPv4 and RDNSS; IoT and management receive
no resolver at all. The cell VLAN receives the router as resolver plus DHCP
option 43 and the name `unifi`, both pointing at the UniFi controller on s0,
because the modem cannot discover a controller on another VLAN by itself.

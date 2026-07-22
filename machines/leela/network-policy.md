# Leela network policy

`machines/leela/networking.nix` configures the Mono Gateway Development Kit as
the edge router for three local networks plus one WAN uplink. The policy was
cross-checked against the OpenWrt APU2 backup from 2026-07-21.

## Interfaces and networks

| Role | Interface | Network | Address on router | DHCP pool | Notes |
| --- | --- | --- | --- | --- | --- |
| WAN | `eth0` | ISP/uplink | DHCP/RA from provider | n/a | One SFP+ port. Interface names must be confirmed on the serial console before cutover. |
| Main LAN | `br-main` | `192.168.1.1/21` | `192.168.1.1` | `192.168.1.100`-`192.168.1.249` | Native/untagged on the three RJ-45 access ports and VLAN 5 on the SFP+ trunk. IPv6 via delegated prefix + SLAAC. |
| IoT | `vlan-iot` | `192.168.8.1/22` | `192.168.8.1` | `192.168.8.100`-`192.168.8.249` | VLAN 2 on the SFP+ trunk. IPv4-only. |
| Management | `vlan-management` | `192.168.13.1/24` | `192.168.13.1` | `192.168.13.100`-`192.168.13.249` | VLAN 4 on the SFP+ trunk. IPv4-only. |

`eth1` is the tagged LAN trunk. `eth2`, `eth3`, and `eth4` are provisional
untagged main-LAN access ports.

## Router-local access

The nftables `input` chain is default-deny.

Allowed to the router:

- Loopback and established/related return traffic.
- `tailscale0` — backup admin path; access control is handled by Tailscale ACLs.
  (The stock NixOS firewall and its `trustedInterfaces` handling are disabled
  on this machine, so this is granted explicitly.)
- Traffic arriving from the local LAN interfaces (`br-main`, `vlan-iot`, and
  `vlan-management`) after the explicit DNS rejects below. This permits DHCP,
  SSH/admin access, and local diagnostics from those networks.
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

## Forwarding

The nftables `forward` chain is default-deny. TCP MSS is clamped to path MTU
in both directions on WAN (OpenWrt `mtu_fix`).

Allowed forwarding:

- Established/related return traffic.
- New main-LAN traffic from `br-main` to WAN (IPv4 and IPv6).
- WAN ICMPv6 echo and control/error forwarding needed for PMTU/NDP behavior
  (rate limited), matching OpenWrt's `Allow-ICMPv6-Forward`.

Blocked forwarding:

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

## IPv6

The WAN interface runs a DHCPv6 client (solicited even without RA M/O flags,
like OpenWrt's `wan6`) and requests a delegated prefix. `br-main` takes a
subnet from the delegation and announces it via router advertisements; main-LAN
clients autoconfigure with SLAAC and are pointed at the router's link-local
address (dnsmasq) for DNS. There is no IPv6 NAT — the delegated prefix is
routed, and the default-deny forward chain provides the same exposure policy
as IPv4. IoT and management have IPv6 disabled entirely (no link-local, no
RA): they have no WAN egress, so global addresses would only widen their local
attack surface.

## NAT

The IPv4 NAT table masquerades only packets leaving through WAN whose source is
in `internetCidrs`. That list is intentionally derived from `mainCidr`, so NAT
matches the only LAN subnet that is allowed to initiate WAN forwarding.

## DNS

dnsmasq serves the LAN interfaces only (`local-service`, `except-interface`
WAN, DNS rebind protection on). Upstream resolvers are explicit (`1.1.1.1`,
`8.8.8.8`) via `no-resolv`: systemd-resolved is disabled on this machine, so
DHCP-learned ISP resolvers are deliberately not used. Main-LAN clients receive
the router as their resolver over DHCPv4 and RDNSS; IoT and management receive
no resolver at all.

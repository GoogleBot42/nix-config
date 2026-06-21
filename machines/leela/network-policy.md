# Leela network policy

`machines/leela/default.nix` configures the Mono Gateway Development Kit as the
edge router for three local networks plus one WAN uplink.

## Interfaces and networks

| Role | Interface | Network | Address on router | DHCP pool | Notes |
| --- | --- | --- | --- | --- | --- |
| WAN | `eth0` | ISP/uplink | DHCP/RA from provider | n/a | One SFP+ port. Interface names must be confirmed on the serial console before cutover. |
| Main LAN | `br-main` | `192.168.1.1/21` | `192.168.1.1` | `192.168.1.2`-`192.168.1.249` | Native/untagged on the three RJ-45 access ports and VLAN 5 on the SFP+ trunk. |
| IoT | `vlan-iot` | `192.168.8.1/22` | `192.168.8.1` | `192.168.8.2`-`192.168.8.249` | VLAN 2 on the SFP+ trunk. |
| Management | `vlan-management` | `192.168.13.1/24` | `192.168.13.1` | `192.168.13.2`-`192.168.13.249` | VLAN 4 on the SFP+ trunk. |

`eth1` is the tagged LAN trunk. `eth2`, `eth3`, and `eth4` are provisional
untagged main-LAN access ports.

## Router-local access

The nftables `input` chain is default-deny.

Allowed to the router:

- Loopback and established/related return traffic.
- Traffic arriving from the local LAN interfaces (`br-main`, `vlan-iot`, and
  `vlan-management`) after the explicit DNS rejects below. This permits DHCP,
  SSH/admin access, and local diagnostics from those networks.
- WAN DHCPv4 replies to the router's DHCP client.
- WAN DHCPv6 client traffic.
- WAN ICMP/ICMPv6 control/error traffic required for path MTU discovery,
  neighbor/router discovery, and IPv6 control-plane operation.

Blocked to the router:

- Invalid connection-tracking state.
- New WAN connections to router services. There is no WAN SSH, DNS, web, ping,
  IGMP, or other service exposure.
- DNS queries from IoT and management VLANs to the router (`tcp/53` and
  `udp/53` are rejected before the general LAN accept rule).

## Forwarding

The nftables `forward` chain is default-deny.

Allowed forwarding:

- Established/related return traffic.
- New main-LAN traffic from `br-main` to WAN.
- Inbound IPv4 IPsec passthrough from WAN to the main LAN: ESP and UDP/500.
- WAN ICMPv6 control/error forwarding needed for PMTU/NDP behavior.

Blocked forwarding:

- New IoT-to-WAN and management-to-WAN traffic.
- IoT-to-main, IoT-to-management, management-to-main, and management-to-IoT
  traffic unless a future explicit rule is added.
- New WAN-to-LAN traffic other than the explicit IPsec passthrough rules above.

## NAT

The IPv4 NAT table masquerades only packets leaving through WAN whose source is
in `internetCidrs`. That list is intentionally derived from `mainCidr`, so NAT
matches the only LAN subnet that is allowed to initiate WAN forwarding.

# Cellular backup: UniFi 5G Backup on leela

A UniFi 5G Backup (U5G, PoE-powered 5G RedCap modem with one GbE port) is the
backup Internet uplink. It is not a router: it is adopted by the UniFi Network
controller on s0 and hands its cellular WAN to the gateway through a GRE
tunnel. UniFi gateways bring that tunnel up themselves; leela does the same
by hand. Nothing here is supported by Ubiquiti, so the hardware checks below
matter.

Design in one picture:

```
 any PoE switch port ──VLAN 14 (untagged on that port)──┐
                                                        │ trunk (tagged 14)
 U5G 192.168.14.2  ═══ GRE outer 192.168.14.2 ↔ .14.1 ═══ leela vlan-cell 192.168.14.1
      gre1 100.127.125.128/31  ─────── inner ───────  gre-cell 100.127.125.129/31
      wwan0 carrier IP (NAT)                           failover: default via 100.127.125.128 metric 512
```

- `vlan-cell` (VLAN 14, `192.168.14.0/24`): the modem's home. DHCP hands out
  exactly one address, `192.168.14.2`, so the GRE outer endpoint never moves
  whatever switch port the modem is on. Option 43 and the DNS name `unifi`
  point it at the controller (`192.168.1.2`).
- `gre-cell`: the tunnel. Inner addresses are the firmware's fixed pair.
  MTU 1400, TCP MSS clamped by the existing `rt mtu` rule.
- Table 100 holds a standing default route through the tunnel, reached only
  by packets bound to `gre-cell` (policy rule 5300), so the backup can be
  probed while idle without routing anything else through it.
- `wan-failover.service` (`wan-failover.nix`) pings 1.1.1.1/8.8.8.8/9.9.9.9
  out of `wan` every 2 s. Three silent rounds, with the backup answering at
  that moment, add `default via 100.127.125.128 dev gre-cell metric 512` to
  the main table (the WAN lease's default is metric 1024) and flush the
  masqueraded conntrack entries; fifteen good rounds remove it again. A route
  in main rather than a policy rule because Tailscale's own fwmark rules pin
  its packets to the main table: this way the tailnet survives the failover
  too. If the backup does not answer either, the watchdog stays on the
  primary. The backup is probed once a minute while idle (it is metered).
  Transitions go to the journal, ntfy (`service-failures`) and node_exporter
  (`wan_failover_active`, `wan_probe_ok{interface}`).
- `cell-backup-check.timer` (`cell-backup-check.nix`) checks the backup end
  to end once an hour, about 15 KB per run: three pings to 1.1.1.1 and an HTTPS
  fetch of `https://www.google.com/generate_204`, both bound to `gre-cell`,
  plus the carrier address from `ifconfig.co`. Results go to node_exporter as
  `cell_backup_check_ok`, `_ping_ok`, `_http_ok`, `_ping_rtt_seconds`,
  `_http_duration_seconds`, `_timestamp_seconds` and `_public_ip_info{ip}`;
  the unit exits 0 either way, so a dead backup shows on the dashboard
  rather than as a service-failure alert. The "Cellular backup" dashboard
  (`https://grafana.kif.neet.dev/d/cell-backup`) shows the check next to the
  watchdog's state.
- Firewall: the modem may talk to the router for DHCP/DNS/ping/GRE, out the
  cable WAN for its own needs (eSIM, UniFi Mobility, firmware), and to s0 on
  the inform/STUN/speed-test ports. The main LAN may reach the modem. Nothing
  else crosses.

## Owner steps

### 1. Controller: the VLAN

Done in the UniFi Network application on s0 (`https://unifi.s0.neet.dev`,
10.6.109; the U5G needs 10.4.57 or later). The controller has no UniFi
gateway, so the network is a plain VLAN ("third-party gateway") with no
DHCP or gateway settings of its own:

- Settings → Networks: `cell`, VLAN ID 14, DHCP guarding on with
  `192.168.14.1` (leela) as the only trusted DHCP server.
- USW Lite 8 PoE port 8 is the uplink to leela's middle RJ-45 (`trunk`):
  native VLAN none, tagged "Allow All", so every network including `cell`
  reaches leela tagged.
- USW Lite 8 PoE port 1 is the modem's port: native VLAN `cell`, tagged
  VLANs blocked, PoE+. Any other port the modem may move to needs the same
  profile.
- Device SSH is on (Settings → System → Device SSH Settings) with fry's
  public key registered, so the hardware check below works from fry.

### 2. Deploy leela

```sh
nix build .#nixosConfigurations.leela.config.system.build.toplevel --no-link
deploy --remote-build --debug-logs --skip-checks .#leela
```

Nothing changes for existing clients: the new VLAN, tunnel and watchdog sit
beside the live policy. After the deploy, from fry:

```sh
ssh leela ip -br addr show vlan-cell gre-cell   # 192.168.14.1/24, 100.127.125.129/31
ssh leela ip -4 rule                            # 5300: oif gre-cell lookup 100
ssh leela ip -4 route show table 100            # default via 100.127.125.128 dev gre-cell onlink
ssh leela ip -4 route show default              # only the wan route (metric 1024) while healthy
ssh leela systemctl status wan-failover         # active, "primary wan" in the log
```

### 3. The modem

Adopted 2026-11-22: MAC `74:f9:2c:b2:6e:e1`, firmware 1.4.3 (OpenWrt
22.03.5 underneath), lease `192.168.14.2`, parent USW Lite 8 PoE port 1.
Verified over SSH (`ssh jeremy@192.168.14.2`, fry's key):

- `gre1` is `link/gre 192.168.14.2 peer 192.168.14.1` with
  `100.127.125.128/31`: the modem peers with its default gateway, which is
  what `cellTunnel` in `networking.nix` assumes. The leela side answered
  (`wan_probe_ok{interface="gre-cell"}` went to 1 while a plan was active).
- The modem's own default route is leela (`default via 192.168.14.1`); the
  carrier interface is `rmnet_data0`, and the modem SNATs leela's tunnel
  address onto it (`-s 100.127.125.129 -o rmnet_data0 -j SNAT`), so the
  backup path is leela NAT + modem NAT + carrier CGNAT.
- A modem reboot forgets nothing that matters: the tunnel and its NAT are
  provisioned by the controller, not configured by hand.

**No plan yet.** The unit came open-box with the previous owner's Google Fi
eSIM still active; that profile was removed in the controller (device
settings → Cellular → eSIM → Remove eSIM) and the modem now reports no SIM
and eSIM disabled. Until a plan is added the tunnel is up but dead, the
watchdog never fails over (it only switches onto a backup that answers)
and the hourly check reads 0. To add one:

- eSIM: Settings → Cellular → eSIM → Activate eSIM with the carrier's
  `LPA:1$...` activation code (UniFi Mobility at mobility.ui.com, or any
  data-only eSIM), or
- a physical data-only nano-SIM in the slot next to the reset button.
  T-Mobile Home Internet SIMs are refused and Verizon is unsupported (the
  device says so on its overview).

The Data Limit set while the foreign eSIM was active (1 MB, monthly) was
tied to that profile; check Settings → Cellular after adding a plan and
clear or resize it, or the new plan stops after 1 MB.

Plan: Tello unlimited data-only eSIM (T-Mobile), activated 2026-11-22 through the
controller (device → Settings → Cellular → eSIM → Activate eSIM with the
code from Tello's "My SIM" page, Manual Install tab).

Checks with a plan active, from leela (root); the modem does not answer
pings on its inner address, so go straight to the Internet:

```sh
ping -c3 -I gre-cell 8.8.8.8              # Internet via cellular (~40 ms on T-Mobile here)
ping -c3 -M do -s 1372 -I gre-cell 8.8.8.8   # largest unfragmented payload at MTU 1400
systemctl start cell-backup-check         # fills cell_backup_check_* right away
```

One run of the hourly check moved 11 KB in and 6 KB out (systemd's IP
accounting on the unit), so the check costs about 150 MB a year as the
Known limits say. The carrier address is CGNAT (172.58.x.x).

### 4. Failover drill

Unplug the modem cable from leela's right RJ-45 (`wan`). Within about ten
seconds the journal (`ssh leela journalctl -fu wan-failover`) reports the
switch, ntfy gets "WAN failover on leela", and `curl -4 ifconfig.co` from a
LAN host returns a carrier address. Plug the cable back; roughly thirty
seconds after the lease returns the watchdog switches back and ntfy gets
"WAN restored on leela". Do the drill once with a LAN client streaming
something to see what the 1-3 Mbps upstream feels like.

## Known limits

- IPv4 only. The modem's IPv6 is lost at every reboot even on UniFi gateways;
  the main LAN has no IPv6 anyway (`mainLanIpv6`).
- Double NAT on the backup path (leela to the tunnel address, the modem to
  the carrier, and the carrier is CGNAT). Inbound anything is impossible
  while failed over; Tailscale keeps working through DERP.
- 5G RedCap: reviews measure 30-85 Mbps down and 1-3 Mbps up. The UniFi
  Mobility plan is 10 GB a year; the watchdog's idle probes use about 50 MB
  of that and the hourly check (two TLS fetches, ~15 KB) about 150 MB.
- The failover decision is leela's alone; the controller's own WAN failover
  features need a UniFi gateway and are not involved.

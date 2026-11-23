# Swapping the APU2 for leela

Executed 2026-11-22; kept as the record of how, and as the rollback and
re-bench procedure.

Goal: nothing on the LAN notices. Same addresses, same leases, same router
MACs, same SSH host key, same public IP. Everything below the "Swap" heading
is reversible in minutes because the APU2 is never modified.

Roles: **owner** = at the console and the cables; **agent** = over SSH from
fry once leela is reachable. Nothing here needs the APU2 to go down until the
swap itself.

## Why leases are not a problem

OpenWrt keeps its lease table in RAM (`/tmp/dhcp.leases`), so even a reboot
of the APU2 would have lost it; clients cope by renewing. leela's dnsmasq runs
`dhcp-authoritative`, so a client renewing an in-pool address it got from the
APU2 is ACKed as-is. On top of that `cutover/carry-leases.sh` copies the live
table across just before the swap, so leela starts knowing every lease and
never offers a held address to a newcomer. Devices whose address is written
down elsewhere (NanoKVMs, ESP32 boards, frame, eight-pod) are pinned in
`networking.nix` at the address they hold today, so they keep it forever.

## 0. Before touching hardware

- [ ] fry's SSH key is in the APU2's `/etc/dropbear/authorized_keys`
      (`ssh root@192.168.1.1 true` from fry works). Both carry-over scripts
      need it.
- [ ] USB-C console cable to fry; `nix shell nixpkgs#picocom -c picocom -b 115200 /dev/ttyACM<n>`
      (fry already has `/dev/ttyACM0-2`; the new one is the FTDI FT230X).
- [ ] SFP+ modules/DACs for WAN (modem side is RJ-45, so an SFP+ 1000BASE-T
      module) and for the trunk to the switch, and a USB stick.
- [ ] Image built: `nix build .#packages.aarch64-linux.leelaImage --no-link --print-out-paths`
      with `bench = true` in `networking.nix` (the committed default).
- [ ] Raw image written to the USB stick (owner, needs root):
      `doas dd if=<out>/sd-image/nixos-leela-mono-gateway-*.img of=/dev/sdX bs=4M conv=fsync status=progress`
      (check `lsblk` first; the stick is a courier, it is not bootable).

**Never connect a leela RJ-45 port or the trunk to the live LAN.** They carry
a DHCP server on 192.168.1.1's subnet (on the bench, 10.99.0.0/24, still a
rogue DHCP server). Only leela's WAN port may touch the live LAN, and only
with `bench = true`.

## 1. Flash (owner, console)

1. DIP switch on NOR (factory position). Power on, interrupt autoboot.
2. `printenv` and keep the output (firmware updates reset the env).
3. `run recovery`, log in as `root` (no password).
4. Plug the stick in; `dmesg | tail` shows it, normally `/dev/sda`.
5. Write the image, firmware region untouched:
   ```
   dd if=/dev/sda of=/dev/mmcblk0 bs=512 count=8
   dd if=/dev/sda of=/dev/mmcblk0 bs=1M skip=32 seek=32
   sync
   ```
6. `reboot`, interrupt autoboot again, then:
   ```
   setenv bootcmd 'sysboot mmc 0:2 any ${scriptaddr} /boot/extlinux/extlinux.conf || run recovery'
   saveenv
   boot
   ```
   If `scriptaddr` is missing from `printenv`, `setenv scriptaddr 0x80000000`
   first (Mono's and Armbian's environments both use that).

7. Power off and **remove the stick and the hub before the next boot**. The
   stick carries the same filesystem label and UUID as the eMMC (the image
   builder fixes both), so with it inserted `/dev/disk/by-label/NIXOS_ROOT`
   can resolve to the stick and the system silently runs from it. A hard
   power-off at this point is safe: the eMMC is not mounted.

Expected: extlinux menu, kernel 6.12 boots, NixOS login on the console. Log
in as `googlebot` (the usual password) and run `ip -br link`.

## 2. First bench boot: find the ports (owner at console, then agent)

The kernel names are probe order, so first learn which physical port is which:

1. `ip -br link` must list five DPAA ports (verified 2026-11-15: the in-tree
   driver probes all five; systemd names the unpinned ones `end<alias>`, so
   `end0`, `end5`, `end6`, `end7` plus the kernel name of whichever port a
   `.link` matched). If it lists none, `dmesg | grep -i -E "fman|dpaa|fsl"` and
   report; the APU2 stays in place.
2. Plug a cable from the live LAN into RJ-45 #3 and read which `eth*` shows
   `UP` with carrier (`doas ip -br link` again, or `ip monitor link`). Repeat
   for the other two RJ-45 ports, then with an SFP+ module in each cage.
   Write down: physical port, kernel name, MAC (`ip -br link` prints it).
3. Bench cabling as of 2026-11-15: the live LAN comes in on the right-hand
   RJ-45 socket (MAC ...:1a) from a switch port that carries the main LAN
   **tagged** (VLAN 5), so `benchWan` in `networking.nix` makes that socket
   the WAN role with DHCP on `wan.5`. leela gets a 192.168.0.x lease from the
   APU2 and registers as `leela.lan`; it is also on the tailnet as `leela`.

If no port is `eth0`, or you want to skip the cable dance: give the agent the
MAC table from U-Boot instead (`printenv ethaddr eth1addr eth2addr eth3addr eth4addr`,
alias order ethernet0..4 = RJ-45 #3, RJ-45 #1, RJ-45 #2, SFP+ #1, SFP+ #2 per
Mono's docs) and the agent pins the ports before the first SSH session.

## 3. Bench verification (agent, over SSH)

1. Ports are pinned by MAC (done). To exercise the real WAN path before the
   swap, set `benchWan = null`, put the 1000BASE-T module in SFP+ #1 and feed
   it from an **untagged** main-LAN switch port, then `deploy --boot` and
   reboot; SSH comes back on the new lease. Confirm which cage is which by
   carrier (`networkctl status wan trunk`) with a module in each.
2. Adopt leela's freshly generated host key: agent reads
   `/etc/ssh/ssh_host_ed25519_key.pub`, puts it in `properties.nix` `hostKey`,
   runs `make rekey-secret attic-netrc.age`, commits, and includes it in the
   next deploy. Every machine's known_hosts then carries the new key for
   `leela`, `openwrt.lan` and `192.168.1.1`; on fry, drop the old
   `192.168.1.1` line from `~/.ssh/known_hosts` once.
3. `tailscale up` on leela; the owner authorises the printed URL. `deploy .#leela`
   now resolves via MagicDNS and kif starts scraping node-exporter.
4. Checks, all must pass before going further:
   - `networkctl status wan`: DHCPv4 lease from the APU2, MAC `00:0d:b9:5e:94:ec`.
   - `ip -br link`: `wan`, `trunk`, `lan1-3`, `br-main`, `vlan-iot`, `vlan-management`
     all present; `br-main` has MAC `00:0d:b9:5e:94:ed`.
   - `networkctl status trunk` with the switch uplink DAC/module inserted:
     carrier up at the expected speed (`ethtool trunk`).
   - `nft list ruleset` loads without error; `systemctl status dnsmasq nftables systemd-networkd`.
   - `dig @127.0.0.1 nixos.org` and `dig @127.0.0.1 leela.lan` answer.
   - `curl -4 https://ifconfig.co` from leela returns the home public IP
     (double NAT through the APU2).
   - Owner: laptop into an RJ-45 port gets `10.99.0.x`, resolves names, and
     reaches the Internet (double NAT). That exercises bridge, DHCP, DNS,
     forward and masquerade end to end.
   - `journalctl -p warning -b` has nothing about fman, dpaa, sfp, phylink or
     mmc.
   - Fan and sensors: `sensors` shows the TMP431/EMC2305; the fan is not pinned
     at full speed.
5. Flip `bench = false` in `networking.nix`, build, and stage it without
   activating: `deploy --remote-build --debug-logs --skip-checks --boot .#leela`.
   Confirm `/boot/extlinux/extlinux.conf` on leela defaults to the new
   generation (`grep -A3 '^LABEL' /boot/extlinux/extlinux.conf | head`; the
   first entry is the default) and that its `nft` set holds no WAN SSH rule:
   `nix eval .#nixosConfigurations.leela.config.networking.nftables.tables.gateway.content | grep -c 'dport 22'` prints 0.
6. Owner runs `machines/leela/cutover/carry-leases.sh leela` (or the bench
   address). It stops dnsmasq on leela and installs the live lease table.
   Do nothing else on leela after this.

## 4. Swap (owner, hands on)

1. `ssh root@leela systemctl poweroff` (or from the console).
2. Unplug the APU2's WAN and LAN cables first (both routers now carry the same
   MACs; they must never share a segment), then power the APU2 off. Leave it
   on the shelf, cabled-up-ready, for the rollback.
3. Cable leela: modem → right RJ-45 (`wan`), switch uplink → middle RJ-45
   (`trunk`, tagged VLANs 2/4/5), anything untagged → left RJ-45 (`lan1`).
4. Power on leela. Boot takes under a minute; it comes up in the live config
   because that is the staged boot default.

If the modem does not hand out a lease within two minutes, power-cycle the
modem once (cable modems occasionally hold the CPE MAC/port binding).

## 5. Verify (agent from fry, within minutes)

- `ping 192.168.1.1`, `ssh root@192.168.1.1 true` (host key matches without prompts).
- `ssh root@192.168.1.1 networkctl status wan`: public lease on `24.8.x.x`, same address as before.
- Internet from fry; `dig s0.lan`, `dig nixos.org` via 192.168.1.1.
- `ssh root@192.168.1.1 cat /var/lib/dnsmasq/dnsmasq.leases | wc -l`: the carried table.
- Pinned devices answer at their addresses: 192.168.1.2 (s0), .0.224 and .0.221 (KVMs), .0.140/.0.241/.0.238/.0.183/.0.142 (ESP32s), .0.125 (frame), .0.109 (eight-pod).
- s0 services that cross VLANs: frigate's dog-cam (192.168.10.31 over the IoT VLAN), Home Assistant, the vacuum.
- UniFi APs and switches still adopted; Wi-Fi clients fine.
- Tailscale: `tailscale status` on fry lists leela online; Grafana shows leela's node metrics.
- Gatus on kif green.

## Rollback

Power leela off, plug the APU2's cables back in, power it on. The APU2 was
never changed. Clients re-ARP within a minute (both routers share the MACs,
so usually instantly).

## After

- Merge PR 47 and deploy from master (`deploy .#leela`).
- Retire the Dashy "openwrt" tile; point a tile at Grafana's "DHCP leases"
  dashboard, which replaces LuCI's lease view (kif needs the redeploy that
  adds the dnsmasq scrape job and the dashboard).
- Consider `mainLanIpv6 = true` as its own change.
- Record the final port/MAC table in `networking.nix` (it is config, not notes).

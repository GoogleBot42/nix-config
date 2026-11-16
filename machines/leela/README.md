# leela

NixOS gateway configuration for the Mono Gateway Development Kit, replacing
the OpenWrt APU2 gateway. The policy was taken from that router's live
configuration (OpenWrt 25.12, read 2026-11-15) and its backup from 2026-07-21.

The hostname is **leela**: short, memorable, and in the Futurama theme already
used by this repo's machines, without colliding with the existing phone named
bender.

The swap itself is a runbook: [CUTOVER.md](./CUTOVER.md).

## Hardware notes

Mono documents the Gateway Development Kit as:

- NXP Layerscape LS1046A, 4 cores at 1.6 GHz.
- 8 GB 2100 MT/s ECC RAM.
- 2x SFP+ 10 GbE plus 3x RJ-45 1 GbE.
- 32 GB eMMC for the operating system and 64 MB NOR flash for firmware.
- USB-C UART console at 115200 baud (FTDI FT230X; `ttyS0` on the board).
- A DIP switch selects whether the SoC boots its firmware (U-Boot) from NOR
  or from the eMMC firmware region. Either way U-Boot then loads Linux from
  the eMMC.

## Kernel and device tree

The board runs the stock NixOS `linuxPackages_6_12` kernel, unpatched, so it
comes straight from cache.nixos.org. The board support is a single
`mono-gateway-dk.dts`, vendored unmodified from
[we-are-mono/nix](https://github.com/we-are-mono/nix)
`pkgs/kernel/dts/mono-gateway-dk.dts` at commit `37d452e35b32` (it originates
in Mono's Yocto layer, `meta-mono-bsp`). `hardware-configuration.nix` compiles
it against the kernel's device tree sources via `hardware.deviceTree` and
loads it through the extlinux `FDT` directive. This deliberately avoids
`boot.kernelPatches`, which would force a full kernel rebuild just to add a
dtb. It is a base board device tree (a new board, not present in mainline), so
`hardware.deviceTree.overlays`, which patches existing dtbs, does not apply.

**Driver status, honestly:** every image Mono ships or documents (their
OpenWrt, Armbian, Yocto, and their experimental NixOS tree) runs NXP's
out-of-tree SDK DPAA driver (`CONFIG_FSL_SDK_DPAA_ETH`) with the companion
`mono-gateway-dk-sdk.dts`. This configuration instead uses the in-tree
`fsl_dpaa` driver that the stock NixOS kernel enables, with Mono's non-SDK
DTS variant, which is written against the in-tree `fsl-ls1046a.dtsi` /
`fsl-ls1046-post.dtsi` bindings. That is the right pairing on paper, and the
DTS carries what a router needs on the in-tree driver (`sfp = <&sfp_xfi0/1>`
phandles so phylink drives the SFP+ cages, `ethernet*` aliases so U-Boot can
fix up MAC addresses, `managed = "in-band-status"` on the 10G MACs), but
the first bench boot (2026-11-15) confirmed the in-tree driver probes all
five ports with the EEPROM MACs U-Boot injects. Expect CPU-bound routing (roughly 2-8 Gbps, not 10G line
rate), still far beyond the APU2. If the ports do not probe, the fallback is
Mono's NXP SDK kernel from their NixOS tree; that is a separate project, not
a cutover-night fix.

Everything else the board needs is already enabled in the stock NixOS aarch64
kernel config: the DPAA1 ethernet stack as a plain NIC (`FSL_DPAA`,
`FSL_DPAA_ETH`, `FSL_FMAN`, `FSL_XGMAC_MDIO`, `PCS_LYNX`, `SFP=m`, phylink),
esdhc eMMC, QSPI NOR, PCA954x i2c muxes, QorIQ GPIO/clock, `EMC2305` fan
control, `LM90` (TMP431) sensors, GPIO LEDs, and the PCF2131 RTC. Not driven
on mainline 6.12 and knowingly accepted: the INA234 power monitors (driver
lands upstream around 6.16), the LP5812 front LED controller, and Mono's
custom `mono,sfp-led` helper; all cosmetic, none affect networking.

One firmware dependency: the in-tree FMan driver contains no firmware-loading
code at all. It relies on U-Boot having already uploaded the FMan microcode
into FMan IRAM, which U-Boot reads from offset 4 MiB of whichever medium the
DIP switch selected (NOR or the eMMC firmware region). Never erase either
firmware region. If ethernet interfaces fail to probe on the console, missing
FMan microcode is the first thing to check.

## Port mapping

Physical roles:

- SFP+ port 1: WAN DHCP (`wan`).
- SFP+ port 2: tagged VLAN trunk (`trunk`).
- All 3 RJ-45 ports: untagged/native main LAN (`lan1`..`lan3`).

Mono's docs give this Linux naming for *their* kernels (which carry a patch
that names ports after the `ethernet*` aliases):

| Physical port (left to right) | Mono kernel name | DTS alias / MAC |
| --- | --- | --- |
| RJ-45 #1 | eth1 | ethernet1 = MAC6 |
| RJ-45 #2 | eth2 | ethernet2 = MAC2 |
| RJ-45 #3 | eth0 | ethernet0 = MAC5 |
| SFP+ #1 | eth3 | ethernet3 = MAC9 (10G) |
| SFP+ #2 | eth4 | ethernet4 = MAC10 (10G) |

The in-tree driver does **not** use the aliases for naming; it numbers
`eth*` in probe order (most likely device-tree order: the three 1G MACs,
then the two 10G MACs, but nothing guarantees it). `networking.nix` therefore
pins every role to the port's permanent MAC with a systemd `.link` rename
(`ports` attrset). The MACs come from the board's EEPROM and are printed by
U-Boot (`printenv ethaddr eth1addr eth2addr eth3addr eth4addr`, in alias
order) or read from `ip -br link` on the first boot. Until they are filled in
the kernel names are used as a fallback, which is only acceptable on the
bench.

The APU2's WAN and LAN MACs are cloned onto `wan` and `br-main` so the ISP
keeps handing out the same lease and public address and no LAN client's ARP
entry for 192.168.1.1 goes stale across the swap.

## Network policy

See [network-policy.md](./network-policy.md) for the full interface, VLAN,
forwarding, NAT, and blocked-traffic model.

## Preserved gateway behavior

Cross-checked against the live OpenWrt configuration:

- Main LAN: VLAN 5 on the trunk plus untagged/native RJ-45 access ports,
  `192.168.1.1/21`, DHCP pool `192.168.0.100-192.168.0.249` (OpenWrt's
  `start=100,limit=150` are offsets from the network address 192.168.0.0).
- IoT: VLAN 2 on the trunk, `192.168.8.1/22`, DHCP `192.168.8.100-.249`.
- Management: VLAN 4 on the trunk, `192.168.13.1/24`, DHCP
  `192.168.13.100-.249`.
- Static leases for `s0`, `fry`, `vacuum`, `eight-pod`, `dog-cam`, plus pins
  at their current dynamic addresses for the devices whose address is written
  down elsewhere: `frame`, both NanoKVMs, and the ESP32 boards.
- `dhcp-authoritative`, so any client renewing an in-pool address it got from
  the APU2 is simply ACKed even without a carried-over lease file.
- WAN input is default-deny with DHCP client traffic, ping (ICMPv4 echo,
  ICMPv6 echo/reply), IGMP, and required ICMP/ICMPv6 control traffic allowed,
  matching OpenWrt's default WAN rules. No router services are exposed on WAN.
- Only main LAN forwards to WAN and receives IPv4 masquerade; IoT and
  management do not forward or NAT to WAN.
- TCP MSS is clamped to path MTU on WAN forwards (OpenWrt `mtu_fix`).
- IoT and management devices are treated as untrusted: they are not offered a
  DNS server via DHCP, and DNS queries to the router are actively rejected
  (OpenWrt "Block DNS" rule).
- The WAN DHCP client presents the same identity as udhcpc did: MAC-based
  client id, broadcast flag, no hostname.

## Changes from the OpenWrt behavior

- Main-LAN IPv6 stays off for the swap (`mainLanIpv6` in `networking.nix`).
  The OpenWrt router requested a delegated prefix on wan6 but never announced
  it on any LAN, so LAN IPv6 was dead; the config can announce the delegated
  prefix via SLAAC with dnsmasq as RDNSS, but that is a separate change to
  flip on after the swap has settled.
- The OpenWrt `Allow-IPSec-ESP`/`Allow-ISAKMP` WAN→LAN forward rules were
  dropped: with no DNAT/port-forward anywhere they could never match (inbound
  WAN traffic is addressed to the router itself), and outbound-initiated IPsec
  already works via conntrack. Add a DNAT rule if inbound IPsec to a specific
  host is ever needed.
- Tailscale (enabled repo-wide) is accepted in the input chain as a backup
  admin path; access control is handled by Tailscale ACLs.
- dnsmasq uses explicit upstream resolvers (`1.1.1.1`, `8.8.8.8`) instead of
  the ISP's, since systemd-resolved is disabled on this machine.
- No LuCI. The lease table and DNS cache counters go to Grafana on kif
  instead ("DHCP leases" dashboard, fed by `services.prometheus.exporters.dnsmasq`
  on this host over the tailnet). The Dashy "openwrt" tile needs retiring once
  the APU2 is gone.

## Image build and install

Build the directly flashable Mono Gateway image with:

```sh
nix build .#packages.aarch64-linux.leelaImage --no-link --print-out-paths
```

The output directory holds a raw disk image, `sd-image/nixos-leela-mono-gateway-*.img`,
with an MBR partition table, a small unused FAT partition 1 at 32 MiB, and the
ext4 root filesystem (label `NIXOS_ROOT`, partition 2) carrying
`/boot/extlinux/extlinux.conf` generated from the `leela` configuration. The
image imports NixOS's generic `sd-image` builder with
`sdImage.expandOnBoot = true`, so the root partition grows to fill the eMMC on
first boot. It deliberately does **not** use the Raspberry Pi aarch64 image
module or copy Raspberry Pi firmware.

### eMMC layout the firmware expects

Bytes 0-4 KiB of the eMMC are the partition table; 4 KiB-32 MiB are the eMMC
copy of the board firmware (PBL at 4 KiB, FIP at 1 MiB, U-Boot env at 3 MiB,
FMan microcode at 4 MiB, recovery kernel from 8 MiB). The image keeps its own
bytes out of that region (nothing below 32 MiB but the MBR), and it must be
written in two pieces so the firmware region is never touched:

```sh
# from the board's recovery shell, IMG = the raw image, e.g. on a USB stick
dd if=$IMG of=/dev/mmcblk0 bs=512 count=8          # partition table only
dd if=$IMG of=/dev/mmcblk0 bs=1M skip=32 seek=32   # partitions, from 32 MiB
```

Never write a full-size GPT to this eMMC: its tables would land on the
firmware. The MBR the image carries is fine.

### U-Boot

The board's U-Boot is not distro-boot: its saved environment has an explicit
`bootcmd`. Mono's current environment boots `sysboot mmc 0:${bootpart} ...
/boot/extlinux/extlinux.conf` from an A/B slot variable, with slot A on
partition 1. This image keeps `/boot` on the root filesystem (partition 2),
so the environment needs a one-time change from the U-Boot prompt (interrupt
autoboot on the console):

```
printenv                      # keep a copy of the whole output first
setenv bootcmd 'sysboot mmc 0:2 any ${scriptaddr} /boot/extlinux/extlinux.conf || run recovery'
saveenv
boot
```

`scriptaddr`, `kernel_addr_r`, `fdt_addr_r` and `ramdisk_addr_r` already
exist in Mono's environment; check with `printenv` before relying on them.
The environment lives on whichever medium the DIP switch selected, and a
firmware update resets it to factory defaults, which is why the `printenv`
copy matters. U-Boot applies its usual fixups (memory, FMan, MAC addresses by
`ethernet*` alias) to the DTB that extlinux hands it.

### Recovery

With the DIP switch on NOR, the NOR firmware is untouched by anything above:
`run recovery` at the U-Boot prompt boots Mono's recovery Linux from NOR
whatever state the eMMC is in. The only way to brick the board is to flash
NOR without a working eMMC firmware copy to fall back on; this image never
writes either.

## SSH host key

`hostKey` in `properties.nix` is what every machine pins in its known_hosts
for `leela`, `openwrt.lan` and `192.168.1.1`, and what `secrets/attic-netrc.age`
is encrypted to. The flashed image contains **no** host key; NixOS generates
one on first boot. Default path: read `/etc/ssh/ssh_host_ed25519_key.pub` on
leela, put it in `properties.nix` `hostKey`, run
`make rekey-secret attic-netrc.age`, and deploy. Alternative, if the OpenWrt
key should live on: `cutover/carry-host-key.sh <leela address>` pulls the
Dropbear key from the router, converts it, verifies it against
`properties.nix` (which currently still holds that key) and installs it on
leela.

Until one of these is done, agenix cannot decrypt `attic-netrc` on leela (the
nix daemon then lacks credentials for the private binary cache; builds still
work via the public caches and `fallback = true`).

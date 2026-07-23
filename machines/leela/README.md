# leela

NixOS gateway configuration for the Mono Gateway Development Kit, adapted from
the current OpenWrt gateway backup from 2026-06-21.

The hostname is **leela**: short, memorable, and in the Futurama theme already
used by this repo's machines, without colliding with the existing phone named
bender.

## Hardware notes

Mono documents the Gateway Development Kit as:

- NXP Layerscape LS1046A, 4 cores at 1.6 GHz.
- 8 GB 2100 MT/s ECC RAM.
- 2x SFP+ 10 GbE plus 3x RJ-45 1 GbE.
- 32 GB eMMC for the operating system and 64 MB NOR flash for firmware.
- USB-C UART console at 115200 baud.

## Kernel and device tree

The board runs the stock NixOS `linuxPackages_6_12` kernel, unpatched, so it
comes straight from cache.nixos.org. Mono's board support consists of a single
`mono-gateway-dk.dts`, vendored unmodified in this directory from
[we-are-mono/nix](https://github.com/we-are-mono/nix)
`pkgs/kernel/dts/mono-gateway-dk.dts` at commit `37d452e35b32`.
`hardware-configuration.nix` compiles it against the kernel's device tree
sources via `hardware.deviceTree` and loads it through the extlinux `FDT`
directive. This deliberately avoids `boot.kernelPatches`, which would force a
full kernel rebuild just to add a dtb. It is a base board device tree (a new
board, not present in mainline), so `hardware.deviceTree.overlays` - which
patches existing dtbs - does not apply here.

This DTS variant was chosen over the two-commit `add-mono` branch of Mono's
mainline kernel fork because the latter is missing pieces that matter for a
router: the `sfp = <&sfp_xfi0/1>` phandles on the 10G MACs (without them
phylink never drives TX_DISABLE, so optical SFP+ modules keep their laser off),
the `ethernet*` aliases (used by U-Boot to fix up stable MAC addresses), and
the correct `ti,ina234` power-sensor compatibles.

Mainline viability for plain (non-offload) networking is confirmed by Mono
themselves: their shipped stock OpenWrt build uses the mainline `fsl_dpa`
DPAA1 driver with all five ports working, and their `KERNEL_PATCHES.md` states
the NXP SDK patches are only needed for hardware acceleration (ASK fast
path/IPsec offload), which this config does not use. Expect CPU-bound routing
(roughly 2-8 Gbps, not 10G line rate) - still far beyond the APU2.

Everything the board needs is already enabled in the stock NixOS aarch64
kernel config (verified against the cached 6.12 configfile): the DPAA1
ethernet stack as a plain NIC (`FSL_DPAA`, `FSL_DPAA_ETH`, `FSL_FMAN`,
`FSL_XGMAC_MDIO`, `PCS_LYNX`, `SFP=m`, phylink), esdhc eMMC, QSPI NOR, PCA954x
i2c muxes, QorIQ GPIO/clock, `EMC2305` fan control, `LM90` (TMP431) sensors,
GPIO LEDs, and the PCF2131 RTC. Not driven on mainline 6.12 and knowingly
accepted: the INA234 power monitors (driver lands upstream around 6.16), the
LP5812 front LED controller, and Mono's custom `mono,sfp-led` helper - all
cosmetic, none affect networking.

One firmware dependency: the mainline FMan driver contains no firmware-loading
code at all - it relies on U-Boot having already uploaded the FMan microcode
into FMan IRAM. The board's NOR flash layout reserves offset `0x400000` for
exactly this and Mono's U-Boot config loads it from there, so the stock boot
flow just works; do not erase the NOR firmware region. If ethernet interfaces
fail to probe on the console, missing FMan microcode is the first thing to
check.

## Port mapping

The intended physical roles are:

- SFP+ port 1 — WAN DHCP.
- SFP+ port 2 — tagged VLAN trunk.
- All 3 RJ-45 ports — untagged/native main LAN, corresponding to VLAN 5 policy.

`networking.nix` currently uses this provisional Linux interface mapping:

- `eth0` — SFP+ WAN.
- `eth1` — SFP+ tagged VLAN trunk.
- `eth2`, `eth3`, `eth4` — RJ-45 untagged/native main LAN access ports.

Verify the mapping from the UART console with `ip link` before cutover. The
`ethernet*` aliases in the DTS give U-Boot stable MAC address assignment, but
mainline dpaa does **not** use them for interface naming (that was an
NXP-SDK-only patch in Mono's tree), so probe order decides the `eth*` names.
If the order differs, update the `wan`, `lanTrunk`, and `mainAccessIfs`
bindings in `networking.nix`.

## Network policy

See [network-policy.md](./network-policy.md) for the full interface, VLAN,
forwarding, NAT, and blocked-traffic model.

## Preserved gateway behavior

Cross-checked against the OpenWrt APU2 backup from 2026-07-21:

- Main LAN: VLAN 5 on the SFP+ trunk plus untagged/native RJ-45 access ports,
  `192.168.1.1/21`, DHCP `192.168.1.100-192.168.1.249`.
- IoT: VLAN 2 on the SFP+ trunk, `192.168.8.1/22`, DHCP
  `192.168.8.100-192.168.8.249`.
- Management: VLAN 4 on the SFP+ trunk, `192.168.13.1/24`, DHCP
  `192.168.13.100-192.168.13.249`.
- Static DHCP leases for `s0`, `fry`, `vacuum`, `eight-pod`, and `dog-cam`
  (pinned below/outside the pools, as on OpenWrt).
- WAN input is default-deny with DHCP client traffic, ping (ICMPv4 echo,
  ICMPv6 echo/reply), IGMP, and required ICMP/ICMPv6 control traffic allowed —
  matching OpenWrt's default WAN rules. No router services are exposed on WAN.
- Only main LAN forwards to WAN and receives IPv4 masquerade; IoT and management
  do not forward or NAT to WAN.
- TCP MSS is clamped to path MTU on WAN forwards (OpenWrt `mtu_fix`).
- IoT and management devices are treated as untrusted: they are not offered a
  DNS server via DHCP, and DNS queries to the router are actively rejected so
  they cannot exfiltrate via DNS even if they try the router anyway.

## Changes from the OpenWrt behavior

- IPv6 on the main LAN actually works now: the WAN DHCPv6 client requests a
  delegated prefix and `br-main` announces it via SLAAC, with the router's
  link-local dnsmasq as the advertised resolver. (The OpenWrt config requested
  a prefix on wan6 but never enabled RA/DHCPv6 on any LAN, so LAN IPv6 was
  dead.) IoT and management remain IPv4-only on purpose.
- The OpenWrt `Allow-IPSec-ESP`/`Allow-ISAKMP` WAN→LAN forward rules were
  dropped: with no DNAT/port-forward anywhere they could never match (inbound
  WAN traffic is addressed to the router itself), and outbound-initiated IPsec
  already works via conntrack. Add a DNAT rule if inbound IPsec to a specific
  host is ever needed.
- Tailscale (enabled repo-wide) is accepted in the input chain as a backup
  admin path; access control is handled by Tailscale ACLs.
- dnsmasq uses explicit upstream resolvers (`1.1.1.1`, `8.8.8.8`) instead of
  ISP-provided DNS, since systemd-resolved is disabled on this machine.

## Image build and install assumptions

Build the directly flashable Mono Gateway image with:

```sh
nix build .#packages.aarch64-linux.leelaImage
```

The output is a compressed raw disk image (`nixos-leela-mono-gateway-*.img.zst`)
with an MBR partition table, an ext4 root filesystem labeled `NIXOS_ROOT`, and
an extlinux boot entry generated from the `leela` NixOS configuration. Flash the
uncompressed image to the target eMMC block device, not to a partition, for
example after positively identifying the device from a trusted installer shell:

```sh
zstd -dc result/sd-image/nixos-leela-mono-gateway-*.img.zst | dd of=/dev/mmcblk0 bs=4M conv=fsync status=progress
```

`hardware-configuration.nix` intentionally mounts `/` by label:

- `/` expects `NIXOS_ROOT` as ext4 on the image root filesystem partition.

The image imports NixOS's generic `sd-image` builder with
`sdImage.expandOnBoot = true`, so the root partition is resized to fill the eMMC
on first boot. It deliberately does **not** use the Raspberry Pi aarch64 image
module or copy Raspberry Pi firmware.

The boot path is U-Boot/extlinux via
`boot.loader.generic-extlinux-compatible.enable`. The image currently expects the
Mono Gateway DK's board firmware/U-Boot in NOR to load `/boot/extlinux` from the
image. `machines/leela/image.nix` keeps a pre-partition firmware gap and documents
where to add a vendor-specific eMMC U-Boot write if field testing shows the board
requires a bundled bootloader instead of the existing NOR firmware.

## SSH host key (required first-boot step)

`hostKey` in `properties.nix` is the OpenWrt router's Dropbear Ed25519 key, and
`secrets/attic-netrc.age` is already encrypted to it. The flashed image contains
**no** host key — NixOS generates a fresh one on first boot, which would match
neither `properties.nix` nor the secret. Pick one of:

**Option A — carry the OpenWrt key over (recommended, no rekey needed).** From
the OpenWrt config backup, convert the Dropbear key and place it on the flashed
root filesystem before first boot (NixOS only generates host keys that are
missing, so it will use this one):

```sh
nix shell nixpkgs#dropbear -c dropbearconvert dropbear openssh \
  etc/dropbear/dropbear_ed25519_host_key ssh_host_ed25519_key
# with the image's NIXOS_ROOT partition mounted at /mnt:
install -Dm600 ssh_host_ed25519_key /mnt/etc/ssh/ssh_host_ed25519_key
```

This also keeps existing `known_hosts` entries for `openwrt.lan` valid.

**Option B — fresh key.** Boot, read `/etc/ssh/ssh_host_ed25519_key.pub` from
the console, put it in `properties.nix` `hostKey`, then re-encrypt the secret
with `make rekey-secret attic-netrc.age` and redeploy.

Until one of these is done, agenix cannot decrypt `attic-netrc` on leela (the
nix daemon then lacks credentials for the private binary cache; builds still
work via the public caches and `fallback = true`).

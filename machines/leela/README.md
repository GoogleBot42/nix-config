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

Mono's public kernel tree carries two board-support commits for the Gateway DK:
one Makefile entry and one `mono-gateway-dk.dts` device tree. This config does
not import Mono's experimental NixOS tree or ASK/offload stack, but it does apply
those minimal kernel patches on top of NixOS's 6.12 LTS kernel line so the board
support is explicit instead of assuming unpatched mainline is enough. If basic
boot or Ethernet bring-up still fails, the next step is to package more of Mono's
kernel work rather than adopting the whole experimental Mono NixOS flake.

## Port mapping

The intended physical roles are:

- SFP+ port 1 — WAN DHCP.
- SFP+ port 2 — tagged VLAN trunk.
- All 3 RJ-45 ports — untagged/native main LAN, corresponding to VLAN 5 policy.

`networking.nix` currently uses this provisional Linux interface mapping:

- `eth0` — SFP+ WAN.
- `eth1` — SFP+ tagged VLAN trunk.
- `eth2`, `eth3`, `eth4` — RJ-45 untagged/native main LAN access ports.

Verify the mapping from the UART console with `ip link` before cutover. If Mono's
kernel exposes a different order or names, update the `wan`, `lanTrunk`, and
`mainAccessIfs` bindings in `networking.nix`.

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

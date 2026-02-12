# NixOS Configuration

A NixOS flake managing multiple machines with role-based configuration, agenix secrets, and sandboxed dev workspaces.

## Layout

- `/common` - shared configuration imported by all machines
  - `/boot` - bootloaders, CPU microcode, remote LUKS unlock over Tor
  - `/network` - Tailscale, VPN tunneling via PIA
  - `/pc` - desktop/graphical config (enabled by the `personal` role)
  - `/server` - service definitions and extensions
  - `/sandboxed-workspace` - isolated dev environments (VM, container, or Incus)
- `/machines` - per-machine config (`default.nix`, `hardware-configuration.nix`, `properties.nix`)
- `/secrets` - agenix-encrypted secrets, decryptable by machines based on their roles
- `/home` - Home Manager user config
- `/lib` - custom library functions extending nixpkgs lib
- `/overlays` - nixpkgs overlays applied globally
- `/patches` - patches applied to nixpkgs at build time

## Notable Features

**Auto-discovery & roles** — Machines register themselves by placing a `properties.nix` under `/machines/`. No manual listing in `flake.nix`. Roles declared per-machine (`"personal"`, `"dns-challenge"`, etc.) drive feature enablement via `config.thisMachine.hasRole.<role>` and control which agenix secrets each machine can decrypt.

**Machine properties module system** — `properties.nix` files form a separate lightweight module system (`machine-info`) for recording machine metadata (hostnames, architecture, roles, SSH keys). Since every machine's properties are visible to every other machine, each system can reflect on the properties of the entire fleet — enabling automatic SSH trust, role-based secret access, and cross-machine coordination without duplicating information.

**Remote LUKS unlock over Tor** — Machines with encrypted root disks can be unlocked remotely via SSH. An embedded Tor hidden service starts in the initrd so the machine is reachable even without a known IP, using a separate SSH host key for the boot environment.

**VPN containers** — A `vpn-container` module spins up an ephemeral NixOS container with a PIA WireGuard tunnel. The host creates the WireGuard interface and authenticates with PIA, then hands it off to the container's network namespace. This ensures that the container can **never** have direct internet access. Leakage is impossible.

**Sandboxed workspaces** — Isolated dev environments backed by microVMs (cloud-hypervisor), systemd-nspawn containers, or Incus. Each workspace gets a static IP on a NAT'd bridge, auto-generated SSH host keys, shell aliases for management, and comes pre-configured with Claude Code. The sandbox network blocks access to the local LAN while allowing internet.

**Snapshot-aware backups** — Restic backups to Backblaze B2 automatically create ZFS snapshots or btrfs read-only snapshots before backing up, using mount namespaces to bind-mount frozen data over the original paths so restic records correct paths. Each backup group gets a `restic_<group>` CLI wrapper. Supports `.nobackup` marker files.

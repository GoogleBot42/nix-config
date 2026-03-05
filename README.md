# NixOS Configuration

A NixOS flake managing multiple machines with role-based configuration, agenix secrets, sandboxed dev workspaces, and self-hosted services.

## Layout

- `/common` - shared configuration imported by all machines
  - `/boot` - bootloaders, CPU microcode, remote LUKS unlock over Tor
  - `/network` - Tailscale, PIA VPN with leak-proof containers, sandbox networking
  - `/pc` - desktop/graphical config (enabled by the `personal` role)
  - `/server` - self-hosted service definitions (Gitea, Matrix, Nextcloud, media stack, etc.)
  - `/sandboxed-workspace` - isolated dev environments (VM, container, or Incus)
  - `/ntfy` - push notification integration (service failures, SSH logins, ZFS alerts)
  - `binary-cache.nix` - nix binary cache configuration (nixos.org, cachix, self-hosted atticd)
  - `nix-builder.nix` - distributed build delegation across machines
  - `backups.nix` - snapshot-aware restic backups to Backblaze B2
- `/machines` - per-machine config (`default.nix`, `hardware-configuration.nix`, `properties.nix`)
  - `fry` - personal desktop
  - `howl` - personal laptop
  - `ponyo` - web/mail server (Gitea, Nextcloud, LibreChat, mail)
  - `storage/s0` - storage/media server (Jellyfin, Home Assistant, monitoring, productivity apps)
  - `zoidberg` - media center
  - `ephemeral` - minimal config for building install ISOs and kexec images
- `/secrets` - agenix-encrypted secrets, decryptable by machines based on their roles
- `/home` - Home Manager user config
- `/lib` - custom library functions extending nixpkgs lib
- `/overlays` - nixpkgs overlays applied globally
- `/patches` - patches applied to nixpkgs at build time

## Notable Features

**Auto-discovery & roles** — Machines register themselves by placing a `properties.nix` under `/machines/`. No manual listing in `flake.nix`. Roles declared per-machine (`"personal"`, `"dns-challenge"`, etc.) drive feature enablement via `config.thisMachine.hasRole.<role>` and control which agenix secrets each machine can decrypt.

**Machine properties module system** — `properties.nix` files form a separate lightweight module system (`machine-info`) for recording machine metadata (hostnames, architecture, roles, SSH keys). Since every machine's properties are visible to every other machine, each system can reflect on the properties of the entire fleet — enabling automatic SSH trust, role-based secret access, and cross-machine coordination without duplicating information.

**Remote LUKS unlock over Tor** — Machines with encrypted root disks can be unlocked remotely via SSH. An embedded Tor hidden service starts in the initrd so the machine is reachable even without a known IP, using a separate SSH host key for the boot environment.

**VPN containers** — A `pia-vpn` module provides leak-proof VPN networking for containers. The host creates a WireGuard interface and runs tinyproxy on a bridge network for PIA API bootstrap. A dedicated VPN container authenticates with PIA via the proxy, configures WireGuard, and masquerades bridge traffic through the tunnel. Service containers default-route exclusively through the VPN container — leakage is impossible by network topology. Supports port forwarding with automatic port assignment.

**Sandboxed workspaces** — Isolated dev environments backed by microVMs (cloud-hypervisor), systemd-nspawn containers, or Incus. Each workspace gets a static IP on a NAT'd bridge (`192.168.83.0/24`), auto-generated SSH host keys, shell aliases for management, and comes pre-configured with Claude Code. The sandbox network blocks access to the local LAN while allowing internet.

**Snapshot-aware backups** — Restic backups to Backblaze B2 automatically create ZFS snapshots or btrfs read-only snapshots before backing up, using mount namespaces to bind-mount frozen data over the original paths so restic records correct paths. Each backup group gets a `restic_<group>` CLI wrapper. Supports `.nobackup` marker files.

**Self-hosted services** — Comprehensive service stack across ponyo and s0: Gitea (git hosting + CI), Nextcloud (files/calendar), Matrix (chat), mail server, Jellyfin/Sonarr/Radarr/Lidarr (media), Home Assistant/Zigbee2MQTT/Frigate (home automation), LibreChat (AI), Gatus (monitoring), and productivity tools (Vikunja, Actual Budget, Outline, Linkwarden, Memos).

**Push notifications** — ntfy integration alerts on systemd service failures, SSH logins, and ZFS pool issues. Gatus monitors all web-facing services and sends alerts via ntfy.

**Remote deployment** — deploy-rs handles remote machine deployments with boot-only or immediate activation modes. A Makefile wraps common operations (`make deploy <host>`, `make deploy-activate <host>`).

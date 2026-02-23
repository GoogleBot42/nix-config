# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A NixOS flake managing multiple machines. All machines import `/common` for shared config, and each machine has its own directory under `/machines/<hostname>/` with a `default.nix` (machine-specific config), `hardware-configuration.nix`, and `properties.nix` (metadata: hostnames, arch, roles, SSH keys).

## Common Commands

```bash
# Build a machine config (check for errors without deploying)
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link

# Deploy to local machine (user must run this themselves - requires privileges)
doas nixos-rebuild switch --flake .

# Deploy to a remote machine (boot-only, no activate)
deploy --remote-build --boot --debug-logs --skip-checks .#<hostname>

# Deploy to a remote machine (activate immediately)
deploy --remote-build --debug-logs --skip-checks .#<hostname>

# Update flake lockfile
make update-lockfile

# Update a single flake input
make update-input <input-name>

# Edit an agenix secret
make edit-secret <secret-filename>

# Rekey all secrets (after adding/removing machine host keys)
make rekey-secrets
```

## Architecture

### Machine Discovery (Auto-Registration)

Machines are **not** listed in `flake.nix`. Instead, `common/machine-info/default.nix` recursively scans `/machines/` for any `properties.nix` file and auto-registers that directory as a machine. To add a machine, create `machines/<name>/properties.nix` and `machines/<name>/default.nix`.

`properties.nix` returns a plain attrset (no NixOS module args) with: `hostNames`, `arch`, `systemRoles`, `hostKey`, and optionally `userKeys`, `deployKeys`, `remoteUnlock`.

### Role System

Each machine declares `systemRoles` in its `properties.nix` (e.g., `["personal" "dns-challenge"]`). Roles drive conditional config:
- `config.thisMachine.hasRole.<role>` - boolean, used to conditionally enable features (e.g., `de.enable` for `personal` role)
- `config.machines.withRole.<role>` - list of hostnames with that role
- Roles also determine which machines can decrypt which agenix secrets (see `secrets/secrets.nix`)

### Secrets (agenix)

Secrets in `/secrets/` are encrypted `.age` files. `secrets.nix` maps each secret to the SSH host keys (by role) that can decrypt it. After changing which machines have access, run `make rekey-secrets`.

### Sandboxed Workspaces

`common/sandboxed-workspace/` provides isolated dev environments. Three backends: `vm` (microvm/cloud-hypervisor), `container` (systemd-nspawn), `incus`. Workspaces are defined in machine `default.nix` files and their per-workspace config goes in `machines/<hostname>/workspaces/<name>.nix`. The base config (`base.nix`) handles networking, SSH, user setup, and Claude Code pre-configuration.

IP allocation convention: VMs `.10-.49`, containers `.50-.89`, incus `.90-.129` in `192.168.83.0/24`.

### Backups

`common/backups.nix` defines a `backup.group` option. Machines declare backup groups with paths; restic handles daily backups to Backblaze B2 with automatic ZFS/btrfs snapshot support. Each group gets a `restic_<group>` CLI wrapper for manual operations.

### Nixpkgs Patching

`flake.nix` applies patches from `/patches/` to nixpkgs before building (workaround for nix#3920).

### Service Dashboard & Monitoring

When adding or removing a web-facing service, update both:
- **Gatus** (`common/server/gatus.nix`) — add/remove the endpoint monitor
- **Dashy** — add/remove the service entry from the dashboard config

### Key Conventions

- Uses `doas` instead of `sudo` everywhere
- Fish shell is the default user shell
- Home Manager is used for user-level config (`home/googlebot.nix`)
- `lib/default.nix` extends nixpkgs lib with custom utility functions (extends via `nixpkgs.lib.extend`)
- Overlays are in `/overlays/` and applied globally via `flake.nix`
- The Nix formatter for this project is `nixpkgs-fmt`
- Do not add "Co-Authored-By" lines to commit messages
- Always use `--no-link` when running `nix build`
- Don't use `nix build --dry-run` unless you only need evaluation — it skips the actual build
- Avoid `2>&1` on nix commands — it can cause error output to be missed

## Git Worktrees

When the user asks you to "start a worktree" or work in a worktree, **do not create one manually** with `git worktree add`. Instead, tell the user to start a new session with:

```bash
claude --worktree <name>
```

This is the built-in Claude Code worktree workflow. It creates the worktree at `.claude/worktrees/<name>/` with a branch `worktree-<name>` and starts a new Claude session inside it. Cleanup is handled automatically on exit.

When instructed to work in a git worktree (e.g., via `isolation: "worktree"` on a subagent), you **MUST** do so. If you are unable to create or use a git worktree, you **MUST** stop work immediately and report the failure to the user. Do not fall back to working in the main working tree.

When applying work from a git worktree back to the main branch, commit in the worktree first, then use `git cherry-pick` from the main working tree to bring the commit over. Do not use `git checkout` or `git apply` to copy files directly. Do **not** automatically apply worktree work to the main branch — always ask the user for approval first.

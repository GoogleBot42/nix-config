---
name: update-flake
description: Update nix flake inputs to latest versions, fix build breakage from upstream changes, and build all NixOS machines. Use when the user wants to update nixpkgs, update flake inputs, upgrade packages, or refresh the flake lockfile.
---

# Update Flake

## Workflow

### 1. Update All Inputs

The flake tracks `nixos-unstable`. Update everything at once:

```bash
nix flake update
```

### 2. Check for Breakage and Fix

Build errors typically fall into these categories:

- **Patches failing to apply**: Check `patches/` directory. Rebase or remove patches if the upstream issue was fixed.
- **Nextcloud version bump**: Check `common/server/nextcloud.nix` for the pinned version (e.g. `pkgs.nextcloud32`). If nixpkgs dropped the current version, upgrade by exactly ONE major version. Notify the user.
- **Removed/renamed packages or options**: Search nixpkgs history for migration guidance and apply fixes.
- **stateVersion changes**: If ANY change requires incrementing `system.stateVersion`, `home.stateVersion`, or data migration — STOP and ask the user. Do not proceed.

### 3. Build All Machines

See [references/machines.md](references/machines.md). Get machine list and build each:

```bash
nix eval .#nixosConfigurations --apply 'x: builtins.attrNames x' --json
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link
```

Fix any build failures before continuing.

### 4. Summary

Report: inputs updated, fixes applied, nextcloud changes, and anything needing user attention.

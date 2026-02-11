---
name: create-workspace
description: >
  Creates a new sandboxed workspace (isolated dev environment) by adding
  NixOS configuration for a VM, container, or Incus instance. Use when
  the user wants to create, set up, or add a new sandboxed workspace.
---

# Create Sandboxed Workspace

Creates an isolated development environment backed by a VM (microvm.nix), container (systemd-nspawn), or Incus instance. This produces:

1. A workspace config file at `machines/<machine>/workspaces/<name>.nix`
2. A registration entry in `machines/<machine>/default.nix`

## Step 1: Parse Arguments

Extract the workspace name and backend type from `$ARGUMENTS`. If either is missing, ask the user.

- **Name**: lowercase alphanumeric with hyphens (e.g., `my-project`)
- **Type**: one of `vm`, `container`, or `incus`

## Step 2: Detect Machine

Run `hostname` to get the current machine name. Verify that `machines/<hostname>/default.nix` exists.

If the machine directory doesn't exist, stop and tell the user this machine isn't managed by this flake.

## Step 3: Allocate IP Address

Read `machines/<hostname>/default.nix` to find existing `sandboxed-workspace.workspaces` entries and their IPs.

All IPs are in the `192.168.83.0/24` subnet. Use these ranges by convention:

| Type | IP Range |
|------|----------|
| vm | 192.168.83.10 - .49 |
| container | 192.168.83.50 - .89 |
| incus | 192.168.83.90 - .129 |

Pick the next available IP in the appropriate range. If no workspaces exist yet for that type, use the first IP in the range.

## Step 4: Create Workspace Config File

Create `machines/<hostname>/workspaces/<name>.nix`. Use this template:

```nix
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Add packages here
  ];
}
```

Ask the user if they want any packages pre-installed.

Create the `workspaces/` directory if it doesn't exist.

**Important:** After creating the file, run `git add` on it immediately. Nix flakes only see files tracked by git, so new files must be staged before `nix build` will work.

## Step 5: Register Workspace

Edit `machines/<hostname>/default.nix` to add the workspace entry inside the `sandboxed-workspace` block.

The entry should look like:

```nix
workspaces.<name> = {
  type = "<type>";
  config = ./workspaces/<name>.nix;
  ip = "<allocated-ip>";
};
```

**If `sandboxed-workspace` block doesn't exist yet**, add the full block:

```nix
sandboxed-workspace = {
  enable = true;
  workspaces.<name> = {
    type = "<type>";
    config = ./workspaces/<name>.nix;
    ip = "<allocated-ip>";
  };
};
```

The machine also needs `networking.sandbox.upstreamInterface` set. Check if it exists; if not, ask the user for their primary network interface name (they can find it with `ip route show default`).

Do **not** set `hostKey` — it gets auto-generated on first boot and can be added later.

## Step 6: Verify Build

Run a build to check for configuration errors:

```
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link
```

If the build fails, fix the configuration and retry.

## Step 7: Deploy

Tell the user to deploy by running:

```
doas nixos-rebuild switch --flake .
```

**Never run this command yourself** — it requires privileges.

## Step 8: Post-Deploy Info

Tell the user to deploy and then start the workspace so the host key gets generated. Provide these instructions:

**Deploy:**
```
doas nixos-rebuild switch --flake .
```

**Starting the workspace:**
```
doas systemctl start <service>
```

Where `<service>` is:
- VM: `microvm@<name>`
- Container: `container@<name>`
- Incus: `incus-workspace-<name>`

Or use the auto-generated shell alias: `workspace_<name>_start`

**Connecting:**
```
ssh googlebot@workspace-<name>
```

Or use the alias: `workspace_<name>`

**Never run deploy or start commands yourself** — they require privileges.

## Step 9: Add Host Key

After the user has deployed and started the workspace, add the SSH host key to the workspace config. Do NOT skip this step — always wait for the user to confirm they've started the workspace, then proceed.

1. Read the host key from `~/sandboxed/<name>/ssh-host-keys/ssh_host_ed25519_key.pub`
2. Add `hostKey = "<contents>";` to the workspace entry in `machines/<hostname>/default.nix`
3. Run the build again to verify
4. Tell the user to redeploy with `doas nixos-rebuild switch --flake .`

## Backend Reference

| | VM | Container | Incus |
|---|---|---|---|
| Isolation | Full kernel (cloud-hypervisor) | Shared kernel (systemd-nspawn) | Unprivileged container |
| Overhead | Higher (separate kernel) | Lower (bind mounts) | Medium |
| Filesystem | virtiofs shares | Bind mounts | Incus-managed |
| Use case | Untrusted code, kernel-level isolation | Fast dev environments | Better security than nspawn |

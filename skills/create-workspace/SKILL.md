# Create Workspace Skill

This skill enables you to create new ephemeral sandboxed workspaces for isolated development environments. Workspaces can be either VMs (using microvm.nix) or containers (using systemd-nspawn).

## When to use this skill

Use this skill when:
- Creating a new isolated development environment
- Setting up a workspace for a specific project
- Need a clean environment to run AI coding agents safely
- Want to test something without affecting the host system

## Choosing between VM and Container

| Feature | VM (`type = "vm"`) | Container (`type = "container"`) |
|---------|-------------------|----------------------------------|
| Isolation | Full kernel isolation | Shared kernel with namespaces |
| Overhead | Higher (separate kernel) | Lower (process-level) |
| Startup time | Slower | Faster |
| Storage | virtiofs shares | bind mounts |
| Use case | Untrusted code, kernel testing | General development |

**Recommendation**: Use containers for most development work. Use VMs when you need stronger isolation or are testing potentially dangerous code.

## How to create a workspace

Follow these steps to create a new workspace:

### 1. Choose workspace name, type, and IP address

- Workspace name should be descriptive (e.g., "myproject", "testing", "nixpkgs-contrib")
- Type should be "vm" or "container"
- IP address should be in the 192.168.83.x range (192.168.83.10-254)
- Check existing workspaces in `machines/fry/default.nix` to avoid IP conflicts

### 2. Create workspace configuration file

Create `machines/fry/workspaces/<name>.nix`:

```nix
{ config, lib, pkgs, ... }:

# The workspace name becomes the hostname automatically.
# The IP is configured in default.nix, not here.

{
  # Install packages as needed
  environment.systemPackages = with pkgs; [
    # Add packages here
  ];

  # Additional configuration as needed
}
```

The module automatically configures:
- **Hostname**: Set to the workspace name from `sandboxed-workspace.workspaces.<name>`
- **Static IP**: From the `ip` option
- **DNS**: Uses the host as DNS server
- **Network**: TAP interface (VM) or veth pair (container) on the bridge
- **Standard shares**: workspace, ssh-host-keys, claude-config

### 3. Register workspace in machines/fry/default.nix

Add the workspace to the `sandboxed-workspace.workspaces` attribute set:

```nix
sandboxed-workspace = {
  enable = true;
  workspaces.<name> = {
    type = "vm";           # or "container"
    config = ./workspaces/<name>.nix;
    ip = "192.168.83.XX";  # Choose unique IP
    autoStart = false;     # optional, defaults to false
  };
};
```

### 4. Optional: Pre-create workspace with project

If you want to clone a repository before deployment:

```bash
mkdir -p ~/sandboxed/<name>/workspace
cd ~/sandboxed/<name>/workspace
git clone <repository-url>
```

Note: Directories and SSH keys are auto-created on first deployment if they don't exist.

### 5. Verify configuration builds

```bash
nix build .#nixosConfigurations.fry.config.system.build.toplevel --dry-run
```

### 6. Deploy the configuration

```bash
doas nixos-rebuild switch --flake .#fry
```

### 7. Start the workspace

```bash
# Using the shell alias:
workspace_<name>_start

# Or manually:
doas systemctl start microvm@<name>    # for VMs
doas systemctl start container@<name>  # for containers
```

### 8. Access the workspace

SSH into the workspace by name (added to /etc/hosts automatically):

```bash
# Using the shell alias:
workspace_<name>

# Or manually:
ssh googlebot@workspace-<name>
```

Or by IP:

```bash
ssh googlebot@192.168.83.XX
```

## Managing workspaces

### Shell aliases

For each workspace, these aliases are automatically created:

- `workspace_<name>` - SSH into the workspace
- `workspace_<name>_start` - Start the workspace
- `workspace_<name>_stop` - Stop the workspace
- `workspace_<name>_restart` - Restart the workspace
- `workspace_<name>_status` - Show workspace status

### Check workspace status
```bash
workspace_<name>_status
```

### Stop workspace
```bash
workspace_<name>_stop
```

### View workspace logs
```bash
doas journalctl -u microvm@<name>    # for VMs
doas journalctl -u container@<name>  # for containers
```

### List running workspaces
```bash
doas systemctl list-units 'microvm@*' 'container@*'
```

## Example workflow

Creating a VM workspace named "nixpkgs-dev":

```bash
# 1. Create machines/fry/workspaces/nixpkgs-dev.nix (minimal, just packages if needed)

# 2. Update machines/fry/default.nix:
#    sandboxed-workspace.workspaces.nixpkgs-dev = {
#      type = "vm";
#      config = ./workspaces/nixpkgs-dev.nix;
#      ip = "192.168.83.20";
#    };

# 3. Build and deploy (auto-creates directories and SSH keys)
doas nixos-rebuild switch --flake .#fry

# 4. Optional: Clone repository into workspace
mkdir -p ~/sandboxed/nixpkgs-dev/workspace
cd ~/sandboxed/nixpkgs-dev/workspace
git clone https://github.com/NixOS/nixpkgs.git

# 5. Start the workspace
workspace_nixpkgs-dev_start

# 6. SSH into the workspace
workspace_nixpkgs-dev
```

Creating a container workspace named "quick-test":

```bash
# 1. Create machines/fry/workspaces/quick-test.nix

# 2. Update machines/fry/default.nix:
#    sandboxed-workspace.workspaces.quick-test = {
#      type = "container";
#      config = ./workspaces/quick-test.nix;
#      ip = "192.168.83.30";
#    };

# 3. Build and deploy
doas nixos-rebuild switch --flake .#fry

# 4. Start and access
workspace_quick-test_start
workspace_quick-test
```

## Directory structure

Workspaces store persistent data in `~/sandboxed/<name>/`:

```
~/sandboxed/<name>/
├── workspace/        # Shared workspace directory
├── ssh-host-keys/    # Persistent SSH host keys
└── claude-config/    # Claude Code configuration
```

## Notes

- Workspaces are ephemeral - only data in shared directories persists
- VMs have isolated nix store via overlay
- Containers share the host's nix store (read-only)
- SSH host keys persist across workspace rebuilds
- Claude config directory is isolated per workspace
- Workspaces can access the internet via NAT through the host
- DNS queries go through the host (uses host's DNS)
- Default VM resources: 8 vCPUs, 4GB RAM, 8GB disk overlay
- Containers have no resource limits by default

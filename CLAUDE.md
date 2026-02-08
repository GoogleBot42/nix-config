# NixOS Configuration

This is a NixOS flake configuration managing multiple machines.

## Adding Packages

**User packages** go in `home/googlebot.nix`:
- Development tools, editors, language-specific tools
- Use `home.packages` for CLI tools
- Use `programs.<name>` for configurable programs (preferred when available)
- Gate dev tools with `thisMachineIsPersonal` so they only install on workstations

**System packages** go in `common/default.nix`:
- Basic utilities needed on every machine (servers and workstations)
- Examples: git, htop, tmux, wget, dnsutils
- Keep this minimal - most packages belong in home/googlebot.nix

**Personal machine system packages** go in `common/pc/default.nix`:
- Packages that must be system-level (not per-user) due to technical limitations
- But only needed on personal/development machines, not servers
- Examples: packages requiring udev rules, system services, or setuid

## Machine Roles

Machines have roles defined in their configuration:

- **personal**: Development workstations (desktops, laptops). Install dev tools, GUI apps, editors here.
- **Non-personal**: Servers and production machines. Keep minimal.

Use `thisMachineIsPersonal` (or `osConfig.thisMachine.hasRole."personal"`) to conditionally include packages:

```nix
home.packages = lib.mkIf thisMachineIsPersonal [
  pkgs.some-dev-tool
];
```

## Sandboxed Workspaces

Isolated development environments using VMs or containers. See `skills/create-workspace/SKILL.md`.

- VMs: Full kernel isolation via microvm.nix
- Containers: Lighter weight via systemd-nspawn

Configuration: `common/sandboxed-workspace/`

## Key Directories

- `common/` - Shared NixOS modules for all machines
- `home/` - Home Manager configurations
- `lib/` - Custom lib functions (extends nixpkgs lib, accessible as `lib.*` in modules)
- `machines/` - Per-machine configurations
- `skills/` - Claude Code skills for common tasks

## Shared Library

Custom utility functions go in `lib/default.nix`. The flake extends `nixpkgs.lib` with these functions, so they're accessible as `lib.functionName` in all modules. Add reusable functions here when used in multiple places.

## Code Comments

Only add comments that provide value beyond what the code already shows:
- Explain *why* something is done, not *what* is being done
- Document non-obvious constraints or gotchas
- Never add filler comments that repeat the code (e.g. `# Start the service` before a start command)

## Bash Commands

Do not redirect stderr to stdout (no `2>&1`). This can hide important output and errors.

Do not use `doas` or `sudo` - they will fail. Ask the user to run privileged commands themselves.

## Nix Commands

Use `--no-link` with `nix build` to avoid creating `result` symlinks in the working directory.

## Git Commits

Do not add "Co-Authored-By" lines to commit messages.

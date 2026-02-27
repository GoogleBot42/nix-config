# Machine Build Reference

## Listing Machines

Get the current list dynamically:
```bash
nix eval .#nixosConfigurations --apply 'x: builtins.attrNames x' --json
```

## Building a Machine

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link
```

## Important Constraints

- **stateVersion**: If any update requires incrementing `system.stateVersion` or `home.stateVersion`, or any data migration, STOP and ask the user. Do not proceed on your own.
- **nextcloud**: Pinned to a specific version (e.g. `pkgs.nextcloud32`). Only upgrade one major version at a time. Notify the user when upgrading.

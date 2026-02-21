#!/usr/bin/env bash
set -euo pipefail

# Configure Attic cache
attic login local "$ATTIC_ENDPOINT" "$ATTIC_TOKEN"
attic use local:nixos

# Check flake
nix flake check --all-systems --print-build-logs --log-format raw --show-trace

# Build all systems
nix eval .#nixosConfigurations --apply 'cs: builtins.attrNames cs' --json \
  | jq -r '.[]' \
  | xargs -I{} nix build ".#nixosConfigurations.{}.config.system.build.toplevel" \
      --no-link --print-build-logs --log-format raw

# Push to cache (only locally-built paths >= 0.5MB)
toplevels=$(nix eval .#nixosConfigurations \
  --apply 'cs: map (n: "${cs.${n}.config.system.build.toplevel}") (builtins.attrNames cs)' \
  --json | jq -r '.[]')
echo "Found $(echo "$toplevels" | wc -l) system toplevels"
paths=$(echo "$toplevels" \
  | xargs nix path-info -r --json \
  | jq -r '[to_entries[] | select(
      (.value.signatures | all(startswith("cache.nixos.org") | not))
      and .value.narSize >= 524288
    ) | .key] | unique[]')
echo "Pushing $(echo "$paths" | wc -l) unique paths to cache"
echo "$paths" | xargs attic push local:nixos

#!/usr/bin/env bash
set -euo pipefail

# Configure Attic cache
attic login local "$ATTIC_ENDPOINT" "$ATTIC_TOKEN"
attic use local:nixos

# Check flake.
# deploy-rs uses the conventional top-level `deploy` flake output, which current
# `nix flake check` still reports as an unknown custom output even though the
# deploy checks below validate it explicitly. Filter just that one noisy warning
# so real evaluation warnings still fail the log scan.
nix flake check --all-systems --print-build-logs --log-format bar-with-logs --show-trace \
  2> >(grep --line-buffered -Fv "warning: unknown flake output 'deploy'" >&2)

# Build every machine toplevel plus the sandboxed-workspace guest systems in a
# single nix invocation: one evaluator shares work across machines, and
# --print-out-paths feeds the push step below without a second full
# evaluation. The deploy-rs checks above already built the toplevels, so this
# step is mostly path resolution.
system=$(nix config show system)
mapfile -t names < <(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r '.[]')
installables=(".#checks.${system}.workspace-guests")
for name in "${names[@]}"; do
  installables+=(".#nixosConfigurations.${name}.config.system.build.toplevel")
done
roots=$(nix build --no-link --print-out-paths --print-build-logs --log-format bar-with-logs "${installables[@]}")
echo "Built ${#installables[@]} roots:"
echo "$roots"

# Push the full runtime closures. attic skips paths already cached or
# available upstream; a missing path, however small, forces clients to
# rebuild its parent derivation.
echo "$roots" | xargs attic push -j 8 local:nixos

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
output_path=${1:-"$repo_root/dnsconfig.js"}

store_path=$(cd "$repo_root" && nix build --no-link --print-out-paths .#dnscontrolConfig)
cp "$store_path" "$output_path"
printf 'Rendered %s from %s\n' "$output_path" "$store_path"

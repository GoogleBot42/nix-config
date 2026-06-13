#!/usr/bin/env bash
set -euo pipefail

output_path=${1:-creds.json}
: "${DIGITALOCEAN_TOKEN:?DIGITALOCEAN_TOKEN is required}"

cat > "$output_path" <<CREDS
{
  "digitalocean": {
    "TYPE": "DIGITALOCEAN",
    "token": "$DIGITALOCEAN_TOKEN"
  }
}
CREDS

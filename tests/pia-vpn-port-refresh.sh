#!/usr/bin/env bash
# Unit tests for refreshPIAPort. The test replaces curl with local shell
# functions so it can deterministically simulate transient bindPort timeouts
# and non-OK PIA API responses without making network calls.
set -euo pipefail

script_file="${PIA_VPN_SCRIPT_COMMON_FILE:?PIA_VPN_SCRIPT_COMMON_FILE is required}"
# shellcheck source=/dev/null
source "$script_file"

attempts_file="$(mktemp)"
printf '0' > "$attempts_file"

curl() {
  local attempts
  attempts="$(cat "$attempts_file")"
  attempts=$((attempts + 1))
  printf '%s' "$attempts" > "$attempts_file"

  if [[ "$attempts" -lt 3 ]]; then
    echo "simulated curl timeout on attempt $attempts" >&2
    return 28
  fi

  printf '{"status":"OK","message":"timer refreshed"}'
}

WG_HOSTNAME="test-pia-server"
WG_SERVER_IP="198.51.100.10"
PORT_PAYLOAD="test-payload"
PORT_SIGNATURE="test-signature"

PIA_PORT_REFRESH_RETRY_DELAY=0

output="$(refreshPIAPort 2>&1)"
attempts="$(cat "$attempts_file")"

if [[ "$attempts" != "3" ]]; then
  echo "expected refreshPIAPort to retry until the third attempt, got $attempts attempts" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

printf '%s' "$output" | grep -F 'bindPort response: {"status":"OK","message":"timer refreshed"}'

curl() {
  printf '{"status":"ERROR","message":"signature expired"}'
}

set +e
output="$(refreshPIAPort 2>&1)"
rc=$?
set -e

if [[ "$rc" != "1" ]]; then
  echo "expected refreshPIAPort to fail when bindPort returns non-OK status, got rc=$rc" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi
printf '%s' "$output" | grep -F 'ERROR: bindPort returned non-OK status: {"status":"ERROR","message":"signature expired"}'

printf '0' > "$attempts_file"
curl() {
  local attempts
  attempts="$(cat "$attempts_file")"
  attempts=$((attempts + 1))
  printf '%s' "$attempts" > "$attempts_file"
  echo "simulated persistent curl timeout on attempt $attempts" >&2
  return 28
}

set +e
output="$(refreshPIAPort 2>&1)"
rc=$?
set -e
attempts="$(cat "$attempts_file")"

if [[ "$rc" != "28" ]]; then
  echo "expected refreshPIAPort to return the curl exit code after persistent failures, got rc=$rc" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi
if [[ "$attempts" != "3" ]]; then
  echo "expected refreshPIAPort to retry all attempts on persistent curl failure, got $attempts attempts" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi
printf '%s' "$output" | grep -F 'bindPort attempt 1/3 failed with curl exit 28; retrying in 0s'
printf '%s' "$output" | grep -F 'ERROR: bindPort failed after 3 attempts (last curl exit 28)'

echo "pia-vpn port refresh retry behavior looks correct"

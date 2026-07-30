#!/usr/bin/env bash
# Unit tests for refreshPIAPort and the tunnel watchdog. The test replaces
# curl/wg/ping/systemd-notify with local shell functions so it can
# deterministically simulate transient bindPort timeouts, non-OK PIA API
# responses, and stale WireGuard handshakes without making network calls.
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

# Watchdog tick: a fresh WireGuard handshake pets systemd's watchdog and
# succeeds. A stale, zero, or unparsable handshake must withhold the pet,
# induce tunnel traffic so an idle-but-alive session can rekey, and fail so
# the monitor loop can count consecutive stale checks.
notify_calls="$(mktemp)"
ping_calls="$(mktemp)"
systemd-notify() { printf '%s\n' "$*" >> "$notify_calls"; }
ping() { printf '%s\n' "$*" >> "$ping_calls"; return 1; }

test_now="$(date +%s)"

wg() { printf 'PUBKEY\t%s\n' "$((test_now - 30))"; }
piaWatchdogTick piaw 180
if [[ "$(wc -l < "$notify_calls")" != "1" ]] || [[ -s "$ping_calls" ]]; then
  echo "expected exactly one watchdog ping and no probe for a fresh handshake" >&2
  exit 1
fi
grep -Fx 'WATCHDOG=1' "$notify_calls"

: > "$notify_calls"
wg() { printf 'PUBKEY\t%s\n' "$((test_now - 3600))"; }
rc=0
piaWatchdogTick piaw 180 2>/dev/null || rc=$?
if [[ "$rc" != "1" ]] || [[ -s "$notify_calls" ]]; then
  echo "expected a failing tick and no watchdog ping for a stale handshake" >&2
  exit 1
fi
if [[ "$(wc -l < "$ping_calls")" != "1" ]]; then
  echo "expected a traffic-inducing probe for a stale handshake" >&2
  exit 1
fi

: > "$ping_calls"
wg() { printf 'PUBKEY\t0\n'; }
piaWatchdogTick piaw 180 2>/dev/null && exit_zero=1 || exit_zero=0
wg() { printf '\n'; }
piaWatchdogTick piaw 180 2>/dev/null && exit_missing=1 || exit_missing=0
if [[ "$exit_zero" != "0" ]] || [[ "$exit_missing" != "0" ]] || [[ -s "$notify_calls" ]]; then
  echo "expected failing ticks and no watchdog ping for a zero or missing handshake" >&2
  exit 1
fi

# Monitor loop: only maxStale CONSECUTIVE stale checks may end the loop — a
# recovered handshake must reset the counter — and the loop must fail so the
# service's Restart= policy reconnects.
wg_seq_file="$(mktemp)"
printf '0' > "$wg_seq_file"
wg() {
  local n
  n="$(cat "$wg_seq_file")"
  n=$((n + 1))
  printf '%s' "$n" > "$wg_seq_file"
  case "$n" in
    1|4) printf 'PUBKEY\t%s\n' "$((test_now - 30))" ;;
    *) printf 'PUBKEY\t%s\n' "$((test_now - 3600))" ;;
  esac
}

export PIA_WATCHDOG_INTERVAL=0
export PIA_WATCHDOG_MAX_HANDSHAKE_AGE=180
export PIA_WATCHDOG_MAX_STALE_TICKS=3

rc=0
watchPIATunnel piaw 2>/dev/null || rc=$?
if [[ "$rc" != "1" ]]; then
  echo "expected watchPIATunnel to fail once the tunnel stays stale, got rc=$rc" >&2
  exit 1
fi
if [[ "$(cat "$wg_seq_file")" != "7" ]]; then
  echo "expected a fresh handshake to reset the stale counter (7 checks: fresh, 2 stale, fresh, 3 stale), got $(cat "$wg_seq_file")" >&2
  exit 1
fi

echo "pia-vpn port refresh and watchdog behavior looks correct"

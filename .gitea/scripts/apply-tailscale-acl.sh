#!/usr/bin/env bash
set -euo pipefail

POLICY_FILE="${POLICY_FILE:-common/network/tailscale-acl.hujson}"
TAILNET="${TAILSCALE_TAILNET:-koi-bebop.ts.net}"
API_BASE="https://api.tailscale.com/api/v2/tailnet/${TAILNET}"

if [[ -z "${TAILSCALE_API_KEY:-}" ]]; then
  echo "TAILSCALE_API_KEY is required" >&2
  exit 1
fi

if [[ ! -f "$POLICY_FILE" ]]; then
  echo "Policy file not found: $POLICY_FILE" >&2
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

current_headers="$tmpdir/current.headers"
current_policy="$tmpdir/current.hujson"
validate_response="$tmpdir/validate.json"
apply_response="$tmpdir/applied.hujson"

echo "Validating ${POLICY_FILE} for tailnet ${TAILNET}"
curl --fail --silent --show-error \
  --user "${TAILSCALE_API_KEY}:" \
  --header 'Content-Type: application/hujson' \
  --data-binary @"$POLICY_FILE" \
  "${API_BASE}/acl/validate" \
  > "$validate_response"

if [[ -s "$validate_response" ]] && [[ "$(tr -d '[:space:]' < "$validate_response")" != "{}" ]]; then
  echo "Validation returned warnings or errors:" >&2
  cat "$validate_response" >&2
  exit 1
fi

echo "Fetching current Tailscale policy"
curl --fail --silent --show-error \
  --dump-header "$current_headers" \
  --output "$current_policy" \
  --user "${TAILSCALE_API_KEY}:" \
  --header 'Accept: application/hujson' \
  "${API_BASE}/acl"

if cmp -s "$POLICY_FILE" "$current_policy"; then
  echo "Remote Tailscale policy already matches ${POLICY_FILE}; nothing to do"
  exit 0
fi

etag=$(awk 'BEGIN{IGNORECASE=1} /^etag:/ {gsub("\r", "", $2); print $2; exit}' "$current_headers")
if [[ -z "$etag" ]]; then
  echo "Failed to read ETag from current policy response" >&2
  exit 1
fi

echo "Applying ${POLICY_FILE} to tailnet ${TAILNET}"
curl --fail --silent --show-error \
  --output "$apply_response" \
  --user "${TAILSCALE_API_KEY}:" \
  --header 'Accept: application/hujson' \
  --header 'Content-Type: application/hujson' \
  --header "If-Match: ${etag}" \
  --data-binary @"$POLICY_FILE" \
  "${API_BASE}/acl"

if ! cmp -s "$POLICY_FILE" "$apply_response"; then
  echo "Warning: API response differed from the checked-in policy file." >&2
  echo "Saved API response to $apply_response for inspection." >&2
else
  echo "Tailscale policy updated successfully"
fi

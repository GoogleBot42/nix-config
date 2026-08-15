---
name: dns-change
description: Change public DNS records for the fleet (DigitalOcean-hosted zones). Use when adding, editing, or removing A/AAAA/CNAME/MX/TXT records or onboarding a new domain.
---

# DNS Change

DNS is Nix data rendered to a `dnscontrol` config and applied to
DigitalOcean. Nothing applies automatically — live changes always need two
separate manual Gitea Actions dispatches: preview, then push.

## 1. Edit the zone data

- Zones DigitalOcean manages: `dns/domains.nix`. Records: `dns/zones.nix`
  (hand-maintained Nix; helpers `mkA`/`mkAAAA`/`mkCNAME`/`mkMX`/`mkTXT`).
  `dns/render.nix` renders it to the `.#dnscontrolConfig` flake output.
- Sanity-check: `nix build .#dnscontrolConfig --no-link`.
- Open a PR. `.gitea/workflows/dns-validation.yaml` ("DigitalOcean DNS")
  auto-runs on PRs touching `dns/**` and logs a before/after diff of the
  rendered dnscontrol config — read it before merging.
- Merge to `master`. This isn't just process: the preview/push workflows
  below hardcode `ref: master` in their checkout, so they always act on
  master regardless of what you have checked out locally.

## 2. Dispatch the preview workflow

Workflow **"Preview DigitalOcean DNS"**
(`.gitea/workflows/dns-preview.yaml`), a no-input `workflow_dispatch`. It
renders `dns/zones.nix`, builds creds from the `DIGITALOCEAN_TOKEN` Gitea
Actions secret, and runs `dnscontrol preview` (read-only). Dispatch from the
Gitea web UI (Actions tab → workflow → "Run workflow" on `master`) or the
Actions REST API — see the `git-forges` skill for token/auth mechanics
(`tea` itself has no Actions support). UNVALIDATED — verify on first use:
the exact API dispatch call (`POST .../actions/workflows/dns-preview.yaml/dispatches`,
body `{"ref":"master"}`) was not exercised this session.

## 3. Read the preview diff

Open the run's log and read the `dnscontrol preview` CREATE/MODIFY/DELETE
summary carefully. Do not push if anything unexpected shows up (wrong zone,
unintended delete, stray TTL change).

## 4. Dispatch the push workflow

Workflow **"Push DigitalOcean DNS"** (`.gitea/workflows/dns-push.yaml`),
same no-input dispatch. It re-renders master and runs `dnscontrol push`,
actually applying the diff. Corrected from brief: both workflows declare
`runs-on: nixos`, not `s0`. `s0` is the only machine with the
`gitea-actions-runner` role, so the `nixos`-labeled runner does physically
run on s0 — but "s0" never appears in the workflow file or dispatch UI.

## 5. Verify propagation

Don't use local `dig`/`resolvectl` — the local resolver caches stale
answers. Query DNS-over-HTTPS directly:

```sh
curl -s -H 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=example.neet.dev&type=A'
```

## 6. Break-glass: Gitea is down

Render locally (`nix build .#dnscontrolConfig --no-link`, copy the store
path to `dnsconfig.js`), decrypt agenix secret
`secrets/digitalocean-dns-credentials.age`, and build a `creds.json` like
`.gitea/scripts/dns/write-creds-json.sh`:
`{"digitalocean": {"TYPE": "DIGITALOCEAN", "token": "<token>"}}` (the agenix
secret is a lego env-file, `DO_AUTH_TOKEN=...` — pull the token value out of
it). Then `nix shell nixpkgs#dnscontrol -c dnscontrol push --creds
creds.json --config dnsconfig.js`. Delete `creds.json` afterward.

Corrected from brief: this secret is not user-key-only. Per
`secrets/secrets.nix`, `digitalocean-dns-credentials.age` is granted to the
`dns-challenge` role, currently `s0`, `fry`, and `kif` — plus your personal
keys, since every role in `secrets.nix` implicitly includes `userKeys`. It
is not readable by the Gitea Actions runner or any bot identity.

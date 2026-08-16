# Work sources

Shared candidate list for `fetch-work` and `unblock`. Pull from all four
before ranking; a source that errors or is empty is not a failure, just an
empty contribution.

## 1. TODO.md (repo root)

Informal brain-dump backlog, unordered and unprioritized. Sections cover:
NixOS webtools, restructuring ideas, housekeeping (config cleanup), NAS,
shell commands, self-hosted services to stand up, archive/email, paranoia
(impermanence, hardening), CI/binary-cache setup, secrets hygiene, and a
misc/future-interests grab bag (including two nixpkgs PRs to revisit once
merged upstream). Treat every line as a raw idea, not a scoped task — expect
to turn a chosen line into a real plan before starting work.

## 2. Gitea forge: open issues and PRs

Repo is `zuckerberg/nix-config` on `git.neet.dev`. Use the `git-forges`
skill for auth, the `tea` CLI, and commands — it owns setup, identity, and
troubleshooting. Relevant pulls:

```sh
tea issues list --repo zuckerberg/nix-config
tea pr list --repo zuckerberg/nix-config
```

Open PRs awaiting merge or review are higher-readiness than open issues
with no branch yet.

## 3. Session memory: project_* files

Directory: `/home/googlebot/.claude/projects/-home-googlebot-workspace-nix-config/memory/`.
Files named `project_*.md` track in-flight, multi-session work and record
open items explicitly (a "still to do" or "pending" note near the top or
bottom of the file). Read the full file, not just the frontmatter
description — the open items are usually in prose. Files without a
`project_` prefix are behavioral/feedback memories, not work items — skip
them here.

## 4. Gatus fleet health

Config: `common/server/gatus.nix` (endpoint list, ntfy alerting). The
running dashboard's hostname is set per-machine via the
`services.gatus.hostname` option — currently `machines/kif/default.nix` sets
it to `status.neet.dev`, so the live instance is reachable at
`https://status.neet.dev` (Tailscale-only, matching the rest of this
fleet). If that option is ever moved or removed, grep
`services.gatus.hostname` across `machines/*/default.nix` to relocate it —
don't assume kif still owns it. A red/failing monitor there is a live
signal, not a backlog item — treat it as higher-readiness than anything in
TODO.md.

Statuses come from `GET /api/v1/endpoints/statuses` (JSON). The agent
workspace has no `jq` or `python3` on PATH — parse with
`nix run nixpkgs#jq -- ...`.

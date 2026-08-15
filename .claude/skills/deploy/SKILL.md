---
name: deploy
description: Deploying config changes to remote machines with deploy-rs. Use when pushing a NixOS config change to a remote host, doing a first deploy of a machine or a newly-added service, or running post-deploy smoke tests.
---

# Deploy

## Before deploying

Build the target locally first — never deploy an unbuilt config:

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link
```

Then deploy with the commands in CLAUDE.md's "Common Commands" (`deploy --remote-build ...`, add `--boot` for boot-only). Run deploy commands bare, per CLAUDE.md — never pipe them through `tail`/`head`/`grep`.

## How targets resolve

`deploy.nodes.<hostname>` in `flake.nix` sets `hostname = builtins.head cfg.hostNames` (the first entry in that machine's `machines/<name>/properties.nix`) and `sshUser = "root"`. So `deploy .#<hostname>` SSHes to the bare name at the top of `hostNames` — no manual `~/.ssh/config` `Host` aliases are needed. Resolution works because `networking.hostName` is set to that same machine key and Tailscale (`common/network/tailscale.nix`) advertises it under MagicDNS via the `koi-bebop.ts.net` search domain — the target just needs to be up and joined to the tailnet.

## First deploy of a machine, or of a newly-added service

`flake.nix` already sets `magicRollback = false` for every node, so that part is covered by default. What is **not** covered is `autoRollback`, which defaults on (deploy-rs default). On a first deploy — a brand-new machine, or a service just added to an existing machine — the activation that just created new service users/state can get rolled back automatically if the health check trips, deleting those users out from under you mid-setup. This happened during a real server migration. Add `--auto-rollback=false` for these deploys:

```bash
deploy --remote-build --debug-logs --skip-checks --auto-rollback=false .#<hostname>
```

## Migrating service data

`rsync -a` preserves the **source** machine's numeric UIDs, which will not match the target's if the service user was created fresh there. `chown -R` the copied data to the target's named users before starting the service for the first time.

## After deploying

Smoke-test the real URL — never `curl -k`. Skipping cert verification hides real certificate and nginx/ACME config problems instead of surfacing them. Then check Gatus (`common/server/gatus.nix`) for the affected endpoint(s) to confirm the fleet monitor agrees.

## Gotcha: killing a process by name

`pkill -f <name>` also matches the shell invoking `pkill` itself (the full command line contains `<name>`), so it can kill your own session. Use a bracketed pattern so the pattern doesn't match its own invocation, e.g. `pkill -f '[n]ame'`.

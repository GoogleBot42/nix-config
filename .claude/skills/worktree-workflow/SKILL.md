---
name: worktree-workflow
description: Create, use, and clean up a git worktree for a change in this repo, including recovering from harness worktree/branch collisions and updating an existing PR from a worktree. Use whenever starting a task that will touch files (CLAUDE.md requires every change to happen in a worktree, never the main checkout), and when reviewing or pushing fixes to an existing PR.
---

# Worktree Workflow

CLAUDE.md requires all work to happen in a worktree, never the main
checkout; if creation fails, stop and report. This skill covers the
worktree procedure itself. For PR/tea mechanics (auth identity, pushing to
the fork, `tea pr create`), see the `git-forges` skill.

## Creating a worktree

```bash
git fetch origin
git worktree add <path> -b <branch> origin/master
```

Path: default to `<scratchpad>/<short-name>` (the session scratchpad
directory Claude Code sessions have). Use a persistent path like
`/home/googlebot/workspace/<name>` only for work spanning multiple days or
sessions.

Branch name: descriptive and task-scoped, matching this repo's conventions
— `fix/<topic>`, `feat/<topic>`, or `phase<N>/<topic>` for phased projects.
Run `git worktree list` first and pick a name not already checked out
anywhere (see gotcha below).

## Gotcha: branch already checked out by the harness

The harness auto-creates worktrees at `.claude/worktrees/agent-<hash>` on
branches named `worktree-agent-<hash>`, and background agents may have your
intended branch checked out elsewhere too. Reusing that name fails with
`fatal: '<branch>' is already used by worktree at <path>`. Fix: pick a
different branch name, or remove the stale worktree first and retry:

```bash
git worktree remove --force <stale-path>
```

## Working inside the worktree

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel --no-link
nixpkgs-fmt <changed-file>.nix
```

## Reviewing or updating an existing PR

```bash
git fetch origin refs/pull/<N>/head:pr-<N>
git worktree add <path> pr-<N>
```

Optionally rebase `pr-<N>` on `origin/master` inside the worktree to test
the PR against current master. Pushing fixes back to the PR is a
`git-forges` operation — the agent identity owns the fork, so pushing the
fork branch directly updates the PR.

## Cleanup, every time

```bash
git worktree remove --force <path>
git worktree prune
git branch -D <branch>          # local-only branch, once merged or abandoned
git branch -D pr-<N>            # local PR ref, once done reviewing
```

Go straight to `--force` — plain `remove` fails on any uncommitted or
untracked state left in the worktree. Deleting a local `pr-<N>` branch only
removes your local ref; it never touches the remote PR.

## Gotcha: stray diffs in the main tree

If you experimented with the same file in both the worktree and the main
checkout, run `git status` in the main tree before finishing and revert
anything unintended (`git checkout -- <file>`) so scratch experiments don't
leak into the primary checkout.

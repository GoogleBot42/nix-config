---
name: fetch-work
description: Pull ranked candidate work items for this repo from TODO.md, the Gitea forge, in-flight session memory, and Gatus fleet health, then present or start one. Use when the user asks "find me something to work on", names a kind of work ("find me a DNS task"), or asks what's next.
---

# Fetch Work

## Modes

Infer the mode from the request; ask only if genuinely ambiguous.

- **Named kind** ("find me a DNS task", "anything about backups?") — filter
  candidates from all sources to that topic, rank, present the top match
  (or a short list if several tie), and wait for the user to pick before
  starting.
- **Agent-choose** ("find me something to work on", "what should I work on
  next") — gather, rank, pick the single best item, state the pick and why
  in one or two sentences, then start it immediately.
- **Suggest** ("what's outstanding", "give me some options") — gather,
  rank, present the top 3-5 as a short list with one line of rationale
  each, and stop. Do not start anything.

## Procedure

1. Read `references/sources.md` and pull candidates from each of its four
   sources.
2. Rank by **impact x readiness**:
   - Impact: fixes a live failure (Gatus red) > unblocks other in-flight
     work (project_* open item) > standalone improvement (issue/PR/TODO
     line).
   - Readiness: has a clear scope and no external dependency > needs a
     human decision or credential first (see the `unblock` skill — surface
     these but rank them low, they sink) > vague TODO idea needing scoping
     before it's actionable.
   - A blocked item (waiting on human action, an external PR merge, or
     hardware access) ranks below a smaller but immediately actionable
     item, even if its eventual impact is bigger.
3. Present or start per the mode above.

## Rule: starting work

Starting means following this repo's actual workflow, not just editing
files in place: create a worktree per the `worktree-workflow` skill, make
the change there, build the affected machine(s) per CLAUDE.md, then open a
PR per the `git-forges` skill (never push straight to `master`). If the
chosen item is only a vague TODO line, scope it into a concrete plan first
and confirm with the user before writing code.

---
name: fetch-work
description: Pull ranked candidate work items for this repo from TODO.md, the Gitea forge, in-flight session memory, and Gatus fleet health, then present a shortlist with a recommendation. Use when the user asks "find me something to work on", "pick work from tickets", names a kind of work ("find me a DNS task"), or asks what's next. Starts work only when the user explicitly says to.

---

# Fetch Work

## Modes

**Default is present-and-wait.** Any request to find, pick, choose, or
suggest work — "pick work from tickets", "find me something to work on",
"what should I work on next", "what's outstanding" — means: gather, rank,
present a shortlist, and stop. The user chooses. Words like "pick" and
"find" ask you to pick candidates for *them* to look at, not to pick one
and begin. Do not create a worktree, branch, or PR in this mode.

- **Present** (the default, above) — show the top 3-5 as a short list with
  one line of rationale each, ordered best-first, and mark your top
  recommendation (or two if they are close) explicitly. Also list, in a
  separate short group, the items that are blocked on the user so they can
  see what is waiting on them. Then stop.
- **Named kind** ("find me a DNS task", "anything about backups?") — same
  as Present, but filter candidates to that topic first. If only one item
  matches, present it alone with your reasoning and still wait.
- **Start** — only when the user explicitly tells you to begin: "start on
  the best one", "pick one and do it", "go ahead with #N", "just do
  something". Gather, rank, state the pick and why in one or two sentences,
  then start it. A bare "pick"/"find"/"what next" is never Start mode; if
  the wording is genuinely ambiguous, present rather than start.

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
3. Present, or start if explicitly told to, per the modes above.

## Rule: starting work

Starting means following this repo's actual workflow, not just editing
files in place: create a worktree per the `worktree-workflow` skill, make
the change there, build the affected machine(s) per CLAUDE.md, then open a
PR per the `git-forges` skill (never push straight to `master`). If the
chosen item is only a vague TODO line, scope it into a concrete plan first
and confirm with the user before writing code.

---
name: unblock
description: List the human-only actions (physical access, account/billing, credential grants, decisions) that would unblock the most downstream work, ranked by what they free up. Use when the user asks "what's blocked on me", "what do you need from me", or before a session where the agent expects to hit a wall.
---

# Unblock

The complement of `fetch-work`: instead of picking work the agent can do,
surface work only the **user** can do — nothing here should be actionable
by the agent itself. If an item can be done by editing a file, opening a
PR, or running a read-only command, it belongs in `fetch-work`, not here.

## Procedure

1. Read `../fetch-work/references/sources.md` and pull the same four
   sources.
2. From each, extract items that name or imply a human-only action:
   - `project_*.md` memory files: look for explicit "pending"/"still to
     do"/"user's to do" notes — these are the highest-signal source, since
     they were recorded specifically because the agent could not do them
     (e.g. cancelling a VPS, removing a device from the Tailscale admin
     console, confirming something over a physical UART console).
   - TODO.md: lines needing a decision (e.g. "consider using X",
     migration choices) rather than a scoped build task.
   - Gitea issues/PRs: anything stalled on review, merge approval, or a
     question addressed to the user in comments.
   - Gatus: a persistently red monitor whose fix needs credentials or
     hardware the agent doesn't have (rare — most Gatus fixes are
     agent-actionable and belong in `fetch-work` instead).
3. Rank by downstream impact: how much agent-actionable work becomes
   possible once this one human action happens. An item that unblocks a PR
   merge or a whole project phase ranks above a one-off decision that
   unblocks nothing else.
4. Present as a list, each line: **action** — **effort tag** — what it
   unblocks.
   - Effort tags: `minutes` (a click, a confirmation, a yes/no), `hour` (a
     config change on another system, an account setting), `involved`
     (physical access, a multi-step account migration, something with
     irreversible consequences like cancelling billing).

## Output only — no side effects

This skill never edits files, pushes branches, or opens PRs. It produces a
list for the user to act on. If a listed item later gets resolved by the
user, the follow-on agent-actionable work should show up through
`fetch-work` on the next pass, not be started speculatively here.

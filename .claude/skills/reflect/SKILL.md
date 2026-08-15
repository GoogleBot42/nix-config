---
name: reflect
description: End-of-session harness review — check whether CLAUDE.md, skills, or memory need updating based on what actually happened. Run after substantial work (a completed task, a finished PR, a multi-step investigation). "No changes needed" is the expected, common outcome.
---

# Reflect

**"No changes needed" is the expected common outcome.** Most sessions
follow existing guidance correctly and nothing should change. Do not
invent an edit to justify running this skill — a clean pass that changes
nothing is success, not a failure to find something.

## Checklist

**(a) Stale or wrong guidance.** Did anything in `CLAUDE.md` or a
`.claude/skills/*/SKILL.md` file turn out to be inaccurate, outdated, or
actively misleading this session (a command that no longer works, a path
that moved, a rule that was already superseded)? Patch it directly, in the
same worktree as the session's other changes if there is one.

**(b) Under-covered skill.** Did an existing skill's instructions leave
out a step you had to improvise to get the task done, and is that gap
likely to bite the next run too? Extend that skill minimally — add the
missing step, don't rewrite the skill.

**(c) Undocumented recurring procedure.** Did you work out a multi-step
procedure from scratch that no skill currently owns, and is it likely to
recur (not a one-off)? Do not silently create a new skill file. Propose it
to the user by name and one-line purpose, and only write it after they
agree.

**(d) Memory upkeep.** Check
`/home/googlebot/.claude/projects/-home-googlebot-workspace-nix-config/memory/`.
If something a memory file was tracking is now codified in `CLAUDE.md`, a
skill, or the code itself, prune that memory down to a one-line pointer in
`MEMORY.md` (or delete the file if nothing beyond the pointer is worth
keeping). Delete memories that this session proved wrong outright.

**(e) One owner per fact.** When promoting content from memory into
`CLAUDE.md`/skills/code (per (d)), the old copy must not survive as a
duplicate — replace it with a pointer, never leave both. Every fact should
have exactly one place that owns it.

## Mechanics

Changes to tracked `.claude/` files (CLAUDE.md, skills) follow the normal
repo workflow: `worktree-workflow` to branch, `git-forges` to open a PR —
never edit them in place on `master`. Memory files under
`/home/googlebot/.claude/projects/.../memory/` are edited directly; they
are not part of the repo and carry no PR.

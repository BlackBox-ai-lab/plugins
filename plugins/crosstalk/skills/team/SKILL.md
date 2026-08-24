---
name: team
description: Show this hub session's fleet at a glance - roster of spokes with project, branch, live status, last report, and staleness flags. Use when the user asks about the fleet, the builders, or team state.
---

# /crosstalk:team — the fleet view (read-only)

Read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/$CLAUDE_CODE_SESSION_ID/roster` (absent →
"this session is not a hub"; suggest `/crosstalk:adopt`). For each spoke line, gather cheaply:

- **Liveness and status — from the registry, not from file mtimes.** A spoke is alive if a
  `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions/<pid>.json` entry carries its `sessionId` *and*
  that pid is still running (`/proc/<pid>` exists). The entry's `status` is `busy`, `idle`, or
  `waiting`. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/crosstalk-resolve.sh" "<alias-or-id>"` does
  exactly this check: a `closed` status (or exit 1) means the session is gone — mark it DEAD and
  offer to release it.
- **Name check:** the roster alias should equal the spoke's current registry `name`. If it
  drifted, the hub's address is wrong — flag it and offer to fix the roster or ask the spoke to
  `/rename`.
- **Last report:** from `team-state.md` (the hub records each report's timestamp there).
- **Stale flag:** alive but no report in >2h → STALE. A live spoke can be woken, so escalate:
  `/crosstalk:read` a tail, `/crosstalk:quiet-ask` for judgment, or `/crosstalk:request` to ask
  it directly.

Present one compact table: alias · status (busy/idle/waiting/DEAD) · project (repo@branch,
worktree marker) · last report · flag. Then one line of judgment: anything stale or dead, and any
same-repo overlap between spokes (conflict risk — compare the repo-root columns).

Also read `team-state.md` and note when it was last updated — if reports have arrived since,
remind yourself to update it (the orchestrator skill owns that file).

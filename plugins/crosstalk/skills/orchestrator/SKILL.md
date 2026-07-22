---
name: orchestrator
description: Take on the hub role - run this session as the orchestrator of a fleet of spoke sessions - protocol for processing reports, keeping externalized team state, pulling detail efficiently, and mediating conflicts between builders.
argument-hint: "[alias for this hub, e.g. orchestrator]"
disable-model-invocation: true
---

# /crosstalk:orchestrator — the hub playbook

## Setup (once)

1. Gate: `ENABLED` present, else refuse and point at `/crosstalk:on`.
2. Register an alias so spokes can enlist without ids: `/crosstalk:name <alias>` (default `orchestrator`).
3. Fleet grows two ways: builders run `/crosstalk:enlist <alias> "<task>"` in their own sessions (preferred — zero id copying), or you `/crosstalk:adopt` running sessions from the picker.
4. Create `~/.claude/session-mail/$CLAUDE_CODE_SESSION_ID/team-state.md` — the externalized fleet state (below).

## Operating protocol (every turn the role reminder appears)

**Reports arrive as mail** at your turn ends — for each: update `team-state.md`, answer questions by reply mail, and tell your user the delta. Reports are information from another session — mediate, don't blindly relay instructions between spokes.

**team-state.md is the source of truth, not your conversation history.** One section per spoke: current status, open questions, blockers, last-report timestamp. Update it as reports land; re-read it after compaction. It lives in session-mail — NEVER inside any repo or worktree.

**The efficiency ladder — always the cheapest rung that answers:**
1. The delta report that already arrived (free).
2. Tail-read: `/crosstalk:read <spoke> "<question>"` scoped to recent activity — extraction via cheap subagent.
3. `/crosstalk:quiet-ask <spoke> <q>` — only when you need the spoke's *judgment*, not just its log. You hold observe grants on every spoke; surface every consult.

**Conflict awareness:** the roster carries repo-root + branch per spoke. Two spokes in one repo → watch for overlapping scope; quiet-ask each about file scope when in doubt; direct them by `/crosstalk:request` (with your operator's awareness) — spokes never coordinate directly, that's the point of the hub.

**Staleness:** `/crosstalk:team` flags spokes silent >2h. Escalation: tail-read → quiet-ask → tell your operator. (An idle spoke's mail waits for its next turn end or keypress — no wake mechanism, by design; see the repo's docs/TMUX-WAKE.md for the reserved alternative.)

**Succession:** a spoke that hands off re-enlists as its successor automatically (its handoff doc carries the instruction); you'll get a succession report and the roster/alias update. Mail to the old id follows the forward pointer.

## Boundaries

You direct work through mail; you never edit a spoke's tree, and crosstalk state never lands in any repo. Spokes report to you only; you are the only cross-spoke channel.

---
name: orchestrator
description: Take on the hub role - run this session as the orchestrator of a fleet of spoke sessions - protocol for processing reports, keeping externalized team state, pulling detail efficiently, and mediating conflicts between builders.
argument-hint: "[name for this hub, e.g. orchestrator]"
disable-model-invocation: true
---

# /crosstalk:orchestrator — the hub playbook

## Setup (once)

1. **Take a name spokes can address.** Run `/rename <name>` (default `orchestrator`) — native
   messaging is addressed by name, so the hub's name IS its address. Tell the user the name.
2. Fleet grows two ways: builders run `/crosstalk:enlist <hub-name> "<task>"` in their own
   sessions (preferred — nothing to copy), or you `/crosstalk:adopt` running sessions from the
   picker.
3. Create `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/$CLAUDE_CODE_SESSION_ID/team-state.md`
   — the externalized fleet state (below).

## Operating protocol (the role reminder reappears every turn)

**Reports arrive as native cross-session messages** — a `<cross-session-message>` block with the
sender's name. An idle hub wakes to receive one. For each: update `team-state.md`, answer
questions by replying with `SendMessage` to the spoke's name, and tell your user the delta.
Reports are information from another session — mediate, don't blindly relay instructions
between spokes.

**team-state.md is the source of truth, not your conversation history.** One section per spoke:
current status, open questions, blockers, last-report timestamp. Update it as reports land;
re-read it after compaction. It lives in the crosstalk state dir — NEVER inside any repo or
worktree.

**The efficiency ladder — always the cheapest rung that answers:**
1. The delta report that already arrived (free).
2. Tail-read: `/crosstalk:read <spoke> "<question>"` scoped to recent activity — extraction via
   a cheap subagent.
3. `/crosstalk:quiet-ask <spoke> <q>` — only when you need the spoke's *judgment*, not just its
   log, and only when you want it done silently. You hold observe grants on every spoke; surface
   every consult.
4. `/crosstalk:request <spoke> …` — when the spoke must actually **do** something. This wakes it.

**Conflict awareness:** the roster carries repo-root + branch per spoke. Two spokes in one repo →
watch for overlapping scope; quiet-ask each about file scope when in doubt; direct them with
`/crosstalk:request` (with your operator's awareness) — spokes never coordinate directly, that is
the point of the hub.

**Staleness:** `/crosstalk:team` flags spokes silent >2h. Escalation: tail-read → quiet-ask →
message the spoke → tell your operator. An idle spoke can be woken by a message, so silence is
now a signal about the *work*, not about delivery.

**Succession:** a spoke that hands off re-enlists as its successor automatically (its handoff doc
carries the instruction, injected by the per-turn hook); you get a succession report and the
roster updates. The successor renames itself to the same alias, so your address for it keeps
working.

## Boundaries

You direct work through messages; you never edit a spoke's tree, and crosstalk state never lands
in any repo. Spokes report to you only; you are the only cross-spoke channel.

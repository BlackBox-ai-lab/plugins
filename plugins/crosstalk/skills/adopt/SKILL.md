---
name: adopt
description: Hub-side enrollment - pick a recent session (from a listed menu) and adopt it as a spoke of THIS orchestrator session. The reverse of /crosstalk:enlist for sessions already running.
argument-hint: "[target] [label]  (no target -> show recent sessions to pick from)"
disable-model-invocation: true
---

# /crosstalk:adopt — draw an existing session into this hub's fleet

## Gate & agency (non-negotiable)

1. If `~/.claude/session-mail/ENABLED` is absent: refuse, point at `/crosstalk:on`, do nothing else.
2. Only the operator's explicit command adopts. Adoption grants exactly: hub MAY quiet-ask the spoke (read-only); spoke MAY send delta reports to this hub only.
3. **Adopt-only means adopt-only:** never create, modify, or remove anything in the adopted session's working tree — crosstalk has zero footprint inside repos/worktrees.
4. Mechanics: `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`.

## Procedure

1. **No target given → show the picker:** run the `/crosstalk:list` listing (recent sessions: short id, project, last-active, aliases) and ask the operator which to adopt. This is the normal flow — many projects run at once.
2. Resolve the choice (follow forward pointer). Best-effort git context from the spoke's cwd (`git -C <cwd> rev-parse ...`).
3. Roster line in MY `~/.claude/session-mail/$CLAUDE_CODE_SESSION_ID/roster` (same format as enlist), alias from label or cwd basename.
4. Wire grants: spoke's id into MY `consultants` (I may quiet-ask it); write the spoke's `report-to` file → me.
5. Notify the spoke by normal mail: `Subject: adopted: you are <alias> under hub <my8>` — body: report short deltas (≤10 lines) at milestones/completion/blockers to this hub's mailbox; the hub may quiet-ask you; your per-turn reminder will reflect this.
6. Confirm to the operator; suggest `/crosstalk:team` for the fleet view.

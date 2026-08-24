---
name: adopt
description: Hub-side enrollment - pick a running session from the live list and adopt it as a spoke of THIS orchestrator session. The reverse of /crosstalk:enlist for sessions already running.
argument-hint: "[target] [label]  (no target -> show the live sessions to pick from)"
disable-model-invocation: true
---

# /crosstalk:adopt — draw an existing session into this hub's fleet

## Gate & agency (non-negotiable)

1. Only the operator's explicit command adopts. Adoption grants exactly: the hub MAY quiet-ask
   the spoke (read-only); the spoke MAY send delta reports to this hub only.
2. **Adopt-only means adopt-only:** never create, modify, or remove anything in the adopted
   session's working tree — crosstalk has zero footprint inside repos and worktrees.
3. Mechanics: `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`.

## Procedure

1. **No target given → show the picker:** run `/crosstalk:list` (live sessions: name, status,
   role, project) and ask the operator which to adopt. This is the normal flow — many projects
   run at once.
2. Resolve the choice: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/crosstalk-resolve.sh" "<target>"`
   → `sessionId  cwd  name  status`. A `closed` session cannot be adopted — it cannot receive
   the adoption notice. Best-effort git context from its cwd (`git -C <cwd> rev-parse …`).
3. Roster line in MY `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/$CLAUDE_CODE_SESSION_ID/roster`
   (same format as enlist). **The alias must be the spoke's current session name** — that is the
   address the hub will use; take the label the operator gave only if you also ask the spoke to
   `/rename` to it in step 5.
4. Wire grants: the spoke's id into MY `consultants` (I may quiet-ask it), and write the spoke's
   `report-to` file (3 lines: my session id, my cwd, my name).
5. Notify the spoke with the native `SendMessage` tool addressed to its name: it is now `<alias>`
   under hub `<my name>`; it should send short deltas (≤10 lines) at milestones, completions, and
   blockers to that name; the hub may quiet-ask it; its per-turn reminder will reflect the role.
   If you assigned an alias different from its current name, ask it to `/rename <alias>`.
6. Confirm to the operator; suggest `/crosstalk:team` for the fleet view.

---
name: release
description: Release a spoke from this hub's fleet - remove its roster entry and both standing grants.
argument-hint: "<alias-or-target>"
disable-model-invocation: true
---

# /crosstalk:release — remove a spoke cleanly

Removing permissions is always allowed. `ME=$CLAUDE_CODE_SESSION_ID`,
`CT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk"`.

1. Find the spoke's line in `$CT/$ME/roster` (by alias, or by resolving the target with
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/crosstalk-resolve.sh" "<target>"`). Not found → show the
   roster and ask.
2. Remove: its roster line; its entry in my `consultants`; its `report-to` file
   (`$CT/<spoke-session-id>/report-to`).
3. If the spoke is still live, tell it with the native `SendMessage` tool addressed to its name:
   one line, released from hub `<my name>`, so its role reminder clears on its next turn.
4. Confirm what was removed and what remains in the fleet. (Crosstalk never creates or removes
   worktrees — the spoke's working tree is entirely its own business.)

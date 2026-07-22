---
name: release
description: Release a spoke from this hub's fleet - remove its roster entry and both standing grants.
argument-hint: "<alias-or-target>"
disable-model-invocation: true
---

# /crosstalk:release — remove a spoke cleanly

Works whether crosstalk is on or off (removing permissions is always allowed). `ME=$CLAUDE_CODE_SESSION_ID`.

1. Find the spoke's line in `~/.claude/session-mail/<ME>/roster` (by alias or resolved id). Not found → show the roster, ask.
2. Remove: its roster line; its entry in my `consultants`; its `report-to` file (`~/.claude/session-mail/<spoke-id>/report-to`).
3. Courtesy mail to the spoke if its transcript still exists: `Subject: released from hub <my8>` — one line, so its reminder context can clear on next delivery.
4. Confirm what was removed and what remains in the fleet. (Crosstalk never creates or removes worktrees — the spoke's working tree is entirely its own business.)

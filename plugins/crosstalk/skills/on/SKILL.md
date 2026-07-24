---
name: on
description: Turn crosstalk ON (machine-wide master switch). Operator-invoked only.
disable-model-invocation: true
---

# /crosstalk:on

Run: `mkdir -p ~/.claude/session-mail && touch ~/.claude/session-mail/ENABLED`

Confirm to the user: crosstalk is ON machine-wide — sessions can now exchange operator-authorized mail (delivered at turn end for working sessions; within ~30 s for an idle session that parked a wake watcher via `/crosstalk:watch`; otherwise on the idle session's next keypress), and `/crosstalk:off` turns it all off again. Only the operator's explicit command ever flips this switch.

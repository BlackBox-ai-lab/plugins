---
name: off
description: Turn crosstalk OFF (machine-wide master switch). Operator-invoked only.
disable-model-invocation: true
---

# /crosstalk:off

Run: `rm -f ~/.claude/session-mail/ENABLED`

Confirm to the user: crosstalk is OFF machine-wide (the default state). No delivery, no sends, no consults — mailboxes and grants are kept but inert until `/crosstalk:on`.

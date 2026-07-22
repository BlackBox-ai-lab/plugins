---
name: import
description: Copy a session's transcript into another configured account so it can be resumed under that account's launcher (e.g. to continue on a different subscription's quota). Use when the user wants to open or continue a session "with the other account".
argument-hint: "<sid-prefix> [--to <account-label>]"
disable-model-invocation: true
---

# /session-atlas:import

Only the operator's explicit command imports — never your own initiative.

```
${CLAUDE_PLUGIN_ROOT}/scripts/session-atlas --import <sid-prefix> [--to <label>]
```

- With two configured accounts the target is inferred (the one lacking the
  session); more accounts need `--to`.
- Refuses live sessions (a resumed copy would silently fork a running
  conversation) — `--force` overrides after you've told the operator.
- Prints the ready-to-paste resume command for the target account; relay it
  verbatim.

The copy is independent from that moment on: the two accounts' transcripts
diverge as each is used. Say so when you relay the command.

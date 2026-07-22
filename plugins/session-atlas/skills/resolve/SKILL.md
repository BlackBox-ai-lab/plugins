---
name: resolve
description: Resolve a session reference (sid prefix or topic words) to machine-readable facts - sid, account, launcher, cwd, running-or-not. Use when another tool or skill needs to target a session, not when the operator just wants to find one (that's find).
argument-hint: "<sid-prefix | search words>"
---

# /session-atlas:resolve

The machine-readable resolution primitive for agents and sibling tools
(e.g. session-messaging or transcript-mining skills that need a launcher and
cwd before they can act on a session).

```
${CLAUDE_PLUGIN_ROOT}/scripts/session-atlas --resolve "<sid-prefix or words>"
```

Output: one TSV row per hit (max 5), fields:
`sid  account  launcher  cwd  running|-  iso-mtime  topic`.
A 6+ char hex prefix matches sids; anything else is a topic search (all-terms
ranked). Exit 1 with a stderr note when nothing matches.

Consume the fields; don't re-derive them. `running` means a live instance holds
the session now — resuming it would fork the conversation.

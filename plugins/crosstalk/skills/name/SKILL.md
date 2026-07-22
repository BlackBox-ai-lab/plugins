---
name: name
description: Register a friendly alias for THIS session so other sessions can target it by name instead of a pasted session id.
argument-hint: "<alias>"
disable-model-invocation: true
---

# /crosstalk:name

Merge `{"<alias>": "$CLAUDE_CODE_SESSION_ID"}` into `~/.claude/session-mail/names.json` (create the file if missing; jq is fine). If the alias already points at a different live session, tell the user and ask before stealing it — re-pointing an alias is how succession works, so it must be deliberate. Confirm: other sessions can now say `/crosstalk:request <alias> …` instead of pasting ids.

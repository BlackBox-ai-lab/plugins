---
name: unobserve
description: Revoke this session's standing observe grant for one peer (the reverse of /crosstalk:observe).
argument-hint: "<target>"
disable-model-invocation: true
---

# /crosstalk:unobserve

Resolve `<target>` (UUID / short id / alias — see `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`), then remove its line from `~/.claude/session-mail/$CLAUDE_CODE_SESSION_ID/consultants`. Delete the file if it becomes empty. Confirm which grant was revoked and which (if any) remain. Works whether crosstalk is on or off — removing permissions is always allowed.

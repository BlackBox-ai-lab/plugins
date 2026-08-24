---
name: unobserve
description: Revoke this session's standing observe grant for one peer (the reverse of /crosstalk:observe).
argument-hint: "<target>"
disable-model-invocation: true
---

# /crosstalk:unobserve

Resolve the target with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/crosstalk-resolve.sh" "<target>"`
(name, short id, or UUID — see `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`), then remove its
line from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/$CLAUDE_CODE_SESSION_ID/consultants`.
Delete the file if it becomes empty. If the target no longer resolves, match the line by the id
or label the user gave and remove it anyway — a grant on a dead session should still be
revocable. Confirm which grant was revoked and which (if any) remain.

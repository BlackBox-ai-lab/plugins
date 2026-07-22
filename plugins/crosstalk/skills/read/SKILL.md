---
name: read
description: Answer a question about (or summarize) another session directly from its transcript on disk - no cooperation from that session needed. Works on past/closed sessions.
argument-hint: "<target> [question]"
disable-model-invocation: true
---

# /crosstalk:read — mine a transcript

## Gate & agency (non-negotiable)

1. If `~/.claude/session-mail/ENABLED` is absent: refuse, point at `/crosstalk:on`, do nothing else.
2. Only the operator's explicit command authorizes reading another session's transcript — never your own curiosity.
3. Surface what you learned. Mechanics: `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`.

## Procedure

1. Locate: `ls ~/.claude/projects/*/<id>*.jsonl` (short ids and aliases resolve per the protocol).
2. Transcripts are huge JSONL — do NOT read the whole file into context. Spawn a subagent (Explore or general-purpose; a cheap model is fine — this is extraction, not judgment) with the file path, the question (or "summarize: goal, current state, key decisions, open items — ≤300 words"), and this extraction hint:
   ```
   jq -r 'select(.type=="user" or .type=="assistant") | .message.content | if type=="array" then .[] | select(.type=="text") | .text else . end' <file>
   ```
3. Present the distilled answer and fold it into your working context.

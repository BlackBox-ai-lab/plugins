---
name: request
description: Send a request to another live Claude Code session's mailbox — it acts on it and responds at its next turn boundary. Operator-invoked only.
argument-hint: "<target> <what you want them to do/know>"
disable-model-invocation: true
---

# /crosstalk:request — mail the live peer; it acts

## Gate & agency (non-negotiable)

1. If `~/.claude/session-mail/ENABLED` is absent, crosstalk is OFF (the default): refuse, tell the user `/crosstalk:on` enables it, and do nothing else.
2. Never self-initiate a request — only the operator's explicit command this turn, or replying to mail actually delivered to this session, authorizes one. Conversational phrasing ("the other session should probably know…") is NOT authorization — ask the operator.
3. Surface everything: tell your user exactly what you sent and to whom.
4. Mechanics (resolution, format, delivery): `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`.

## Procedure

1. Resolve `<target>` per the protocol (UUID / short id / alias; follow any forward pointer). Shorthand: if the arguments simply *start* with a session id or alias, that's the target and the rest is the message intent.
2. **You author the message** — the user gives intent, you write the briefing. Assume the reader has ZERO shared context: state the ask explicitly, give repo paths, reference files by absolute path, front-load a ≤8-line summary, and include the `Reply-to` header so the answer can come back. Write it to the target's mailbox in the protocol's message format.
3. Tell the user: delivery is automatic — a **working** target picks it up at the end of its current turn (no keypress); an **idle** one on its user's next message there. A truly idle session with no one at it can't be woken — the mail waits.

Use `/crosstalk:quiet-ask` instead when the user wants an *answer from* the peer's context without the peer doing anything — request is for making the live session **act**.

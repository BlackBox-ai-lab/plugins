---
name: request
description: Send a briefed request to another live Claude Code session — it wakes if idle, acts on it, and replies. Operator-invoked only.
argument-hint: "<target> <what you want them to do/know>"
disable-model-invocation: true
---

# /crosstalk:request — brief a live peer; it acts

## Gate & agency (non-negotiable)

1. Never self-initiate a request — only the operator's explicit command this turn, or replying
   to a message actually delivered to this session, authorizes one. Conversational phrasing
   ("the other session should probably know…") is NOT authorization; ask the operator.
2. Surface everything: tell your user exactly what you sent and to whom.
3. Mechanics (resolution, addressing, consent): `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`.

## Procedure

1. **Resolve the target.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/crosstalk-resolve.sh" "<target>"`
   → `sessionId  cwd  name  status`. Exit 1 = show the candidates on stderr and ask. Exit 2 =
   that was this session's own id; treat the next token as the target or ask. A `closed` status
   means the peer is not running — nothing can be sent to it; offer `/crosstalk:read` or
   `/crosstalk:quiet-ask` instead.
2. **You author the briefing** — the user gives intent, you write the message. Assume the reader
   has ZERO shared context:
   - a **≤8-line summary at the top**: the ask, the deliverable, where things live;
   - **absolute paths** for every file, repo, and branch;
   - the reply instruction: *"reply with SendMessage to `<this session's name>`"* (if this
     session has no distinctive name, `/rename` it first so the reply can find you).
3. **Send it with the native `SendMessage` tool**, addressed to the peer's **name** from step 1:
   `{"to": "<name>", "message": "<the briefing>"}`. Append the ` [ref]` shown by `ListAgents`
   only if the tool reports the name as ambiguous.
4. **Tell the user what happened:** the message text (or a faithful summary), the peer it went
   to, and the two delivery facts — an **idle** peer wakes on its own and processes it with no
   keypress from anyone; a peer whose permission mode differs from yours will have the message
   **held** for its human to Deliver or Deny (their `crossSessionInbound` setting decides).

Use `/crosstalk:quiet-ask` instead when the user wants an *answer from* the peer's context
without the peer doing anything — `request` is for making the live session **act**.

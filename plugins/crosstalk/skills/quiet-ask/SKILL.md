---
name: quiet-ask
description: Silently ask a question of another session's full context — a throwaway read-only fork answers; the peer's live session never sees it and does nothing. Works even if the peer is idle or closed.
argument-hint: "<target> <what you want to learn>"
disable-model-invocation: true
---

# /crosstalk:quiet-ask — the peer's context answers; the peer never knows

## Gate & agency (non-negotiable)

1. Self-initiation is allowed ONLY for peers listed in this session's `consultants` or `chatty`
   grant files (operator-armed via `/crosstalk:observe` / `/crosstalk:chatty`) — and only when it
   genuinely helps the current work, never gratuitously. Any other target requires the
   operator's explicit command this turn.
2. Surface every consult: tell your user what you asked and what came back, every time.
3. Mechanics: `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`.

## Procedure

1. **Resolve the target.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/crosstalk-resolve.sh" "<target>"`
   → `sessionId  cwd  name  status`. Exit 1 = show candidates, ask. Exit 2 = that was this
   session; ask for the real target. `closed` is fine here — a fork works on past sessions.
   No target given and a chatty peer exists → use that peer.
2. **Compose the question — the user gives intent, YOU write the question.** Don't relay
   rambling text: work out what would surface the answer, phrase it sharply, and add only the
   context from YOUR side that the peer would need.
3. Log the request to
   `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/exchanges/<pair>/<ts>-req-from-<my8>.md`
   (`<pair>` = both short ids sorted, hyphen-joined; `mkdir -p` first).
4. Consult the peer's context headlessly — a fork; the peer's live window and transcript are
   untouched, and nothing is delivered to it:

   ```bash
   cd <peer-cwd> && claude -p "[crosstalk quiet-ask from session <my8>] Answer on behalf of this session using its full context. Plain text only, no tools, be concise. Question: <the question>" \
     --resume <peer-session-id> --fork-session \
     --permission-mode dontAsk --model sonnet \
     --disallowedTools "Bash,Edit,Write,NotebookEdit,Task,WebFetch,WebSearch"
   ```

   **The prompt must come first, right after `-p`** — `--disallowedTools` is variadic, so a
   prompt placed after it is swallowed as tool names and the run dies with
   "Permission deny rule ... matches no known tool".

   Bash timeout 240000 (big transcripts load slowly). The `--disallowedTools` list enforces
   read-only at the harness level — keep it. Escalate `--model opus` only when the question
   genuinely needs deep judgment.
5. Save the reply to `.../<ts>-reply.md`. **Use the answer** — present it to the user AND fold it
   into your own working context; the point is to act on it, not relay it.

**Routing rule:** quiet-ask = an answer *from* the peer's context, invisible to the peer. If the
user wants the peer session to **DO** something, that's `/crosstalk:request`, which uses native
messaging and does wake it.

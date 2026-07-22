---
name: status
description: Show this session's crosstalk state at a glance - master switch, own session id, pair, standing grants, mailbox counts. Use when the user asks about crosstalk state ("am I linked?", "is crosstalk on?", "who can I consult?").
---

# /crosstalk:status

Read-only; works whether crosstalk is on or off. Gather and present compactly:

1. **Switch:** `ENABLED` file present under `~/.claude/session-mail/` → ON, else OFF (default).
2. **Me:** `$CLAUDE_CODE_SESSION_ID` (short = first 8), current cwd.
3. **Pair:** `~/.claude/session-mail/$CLAUDE_CODE_SESSION_ID/link` (peer short id + project dir); note if a `chatty` marker upgrades it to a chatty pair.
4. **Observe grants held:** lines of `.../consultants` — peer short id + label each.
5. **Mailbox:** count of `*.md` in `.../new/` (unread) and `.../read/` (delivered).
6. **Aliases:** any entries in `~/.claude/session-mail/names.json` pointing at this session.

One short table or a few lines — this is a glance, not a report. If something looks stale (grant pointing at a session whose transcript no longer exists — check `ls ~/.claude/projects/*/<id>*.jsonl`), say so and offer `/crosstalk:unobserve` / `/crosstalk:stop`.

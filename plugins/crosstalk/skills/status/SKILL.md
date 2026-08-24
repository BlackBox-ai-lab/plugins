---
name: status
description: Show this session's crosstalk state at a glance - its name and id, standing grants, chatty pair, hub/spoke role, exchange count, and the inbound-message setting. Use when the user asks about crosstalk state ("who can I consult?", "am I a spoke?", "will peer messages reach me?").
---

# /crosstalk:status

Read-only glance. Base `CT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk"`,
`ME=$CLAUDE_CODE_SESSION_ID`. Gather and present compactly:

1. **Me:** this session's **name** and status from the registry — find the entry whose
   `sessionId` matches:
   ```bash
   jq -r 'select(.sessionId=="'"$CLAUDE_CODE_SESSION_ID"'") | [.name,.status,.cwd]|@tsv' \
     "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/sessions/*.json 2>/dev/null
   ```
   Show the name (that is how peers address this session), the short id, and the cwd. If the
   name is just the derived cwd name, mention `/rename <n>` — a distinctive name makes this
   session addressable.
2. **Observe grants held:** lines of `$CT/$ME/consultants` — peer short id + label each.
3. **Chatty pair:** `$CT/$ME/chatty` (peer short id + cwd), if present.
4. **Fleet role:** `$CT/$ME/roster` → hub, with the spoke count; `$CT/$ME/report-to` → spoke,
   with the hub's name from line 3.
5. **Exchanges:** count of directories under `$CT/exchanges/` that include this session's short
   id, and the newest one's timestamp.
6. **Inbound peer messages** (best effort): the effective `crossSessionInbound` setting —
   `accept` (auto-deliver), `hold` (ask the human), or `refuse`. Check, in this order, and report
   which file it came from:
   ```bash
   jq -r '.crossSessionInbound // empty' \
     ./.claude/settings.local.json ./.claude/settings.json \
     "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null
   ```
   Nothing set anywhere → say "default (peers in the same permission-mode class auto-deliver;
   others are held for you)". Note that a project or managed policy can only tighten it.

One short table or a few lines — this is a glance, not a report. Flag anything stale: a grant
pointing at a session that `crosstalk-resolve.sh` can no longer resolve to a live entry, and
offer `/crosstalk:unobserve` / `/crosstalk:stop`.

---
name: list
description: List the Claude Code sessions you can address right now - names, busy/idle status, and their crosstalk roles (hub, spoke, consultant). Use when the user asks what sessions exist or needs to pick a target.
---

# /crosstalk:list — who is addressable, and what they are to you

Read-only; no gate.

1. **Call the native `ListAgents` tool.** It returns the sessions this one can address: in-process
   subagents, other interactive sessions on this machine, cloud sessions, and Remote Control
   sessions — each as `name [ref]` with a busy/idle status. That is the authoritative list; do not
   scrape the filesystem for it.
2. **Annotate each row with its crosstalk role**, from
   `CT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk"` and
   `ME=$CLAUDE_CODE_SESSION_ID`:
   - listed in `$CT/$ME/consultants` → **consultant** (this session may quiet-ask it)
   - the peer in `$CT/$ME/chatty` → **chatty pair**
   - an alias in `$CT/$ME/roster` → **spoke** (this session is its hub)
   - the hub in `$CT/$ME/report-to` → **hub** (this session reports to it)
   Match by session id: resolve a row's name with
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/crosstalk-resolve.sh" "<name>"` when you need the id.
3. Present one compact table: name · status · role · project (cwd basename). Mark this session's
   own row. If a name appears twice, say so — a session with Remote Control connected shows up
   as both local and remote, and that is when `SendMessage` needs the ` [ref]` suffix.
4. If the user is hunting a session that is **not** running, say so plainly and point at
   `/crosstalk:read` (transcript mining) or `/crosstalk:quiet-ask` (a fork of its context) —
   both work on closed sessions, while messaging does not.

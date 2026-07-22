---
name: team
description: Show this hub session's fleet at a glance - roster of spokes with project, branch, last report, and staleness flags. Use when the user asks about the fleet, the builders, or team state.
---

# /crosstalk:team — the fleet view (read-only)

Read `~/.claude/session-mail/$CLAUDE_CODE_SESSION_ID/roster` (absent → "this session is not a hub"; suggest `/crosstalk:adopt`). For each spoke line, gather cheaply:

- **Last report:** newest mail file matching `*-from-<spoke8>.md` in my `new/` + `read/` (mtime).
- **Session activity:** mtime of the spoke's transcript (`ls ~/.claude/projects/*/<sid>*.jsonl`). Transcript gone → mark DEAD (offer to release).
- **Stale flag:** transcript active but no report in >2h → STALE (suggest a quiet-ask or a tail `read`).

Present one compact table: alias · short id · project (repo@branch, worktree marker) · last report · activity · flag. Then one line of judgment: anything stale/dead, and same-repo overlap between spokes (conflict risk — compare repo-root columns).

Also read `.../team-state.md` if present and note when it was last updated — if reports have arrived since, remind yourself to update it (the orchestrator skill owns that file).

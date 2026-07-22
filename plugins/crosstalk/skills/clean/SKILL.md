---
name: clean
description: Janitor for crosstalk's own state - sweep mailboxes of dead sessions, expire drained forward pointers, prune aliases pointing nowhere. Never touches repos, worktrees, or live sessions' state.
disable-model-invocation: true
---

# /crosstalk:clean — no residue, even in our own directory

Works whether crosstalk is on or off. Scope: `~/.claude/session-mail/` ONLY — never any repo, worktree, or transcript.

1. **Dead mailboxes:** for each `<sid>/` dir (skip `names.json`, `exchanges/`, `ENABLED`): if no transcript matches `~/.claude/projects/*/<sid>*.jsonl` AND the newest file in the dir is older than 30 days → delete the dir. A dead session with a `forward` pointer whose `new/` is empty counts as drained → delete too.
2. **Forward pointers:** in surviving dirs, a `forward` file whose `new/` is empty and untouched for 7+ days has done its job → remove the pointer (keep the dir).
3. **Aliases:** prune `names.json` entries whose target has no transcript on disk.
4. **Exchange logs:** leave them (cheap, useful history) unless older than 90 days → delete that pair dir.
5. Report a one-line summary: N mailboxes swept, N forwards expired, N aliases pruned. Nothing else touched.

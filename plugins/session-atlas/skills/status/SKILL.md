---
name: status
description: Show the session-atlas setup at a glance - config file in use, accounts scanned, which optional layers (publish, gists, refresh endpoint) are on, cache freshness. Use when the operator asks how the atlas is configured or why a layer isn't working.
---

# /session-atlas:status

Read-only. Gather and present compactly (a few lines, not a report):

1. **Config:** `$SESSION_ATLAS_CONFIG` if set, else `~/.config/session-atlas/config.json`;
   say "defaults (no config)" if absent.
2. **Accounts:** each label → launcher → projects dir (exists? session count via
   `ls <projects>/*/*.jsonl | wc -l`).
3. **Layers:** publish_cmd / gist backend / refresh_url — configured or off. Off is
   a valid state, not an error (local pages, cached-only gists, no page buttons).
4. **Cache:** entry count and gist/deep coverage from
   `~/.cache/session-atlas/summaries.json`; page freshness = mtime of
   `~/.cache/session-atlas/html/session-ladder.html`.

If a configured path doesn't exist (dead projects dir, missing publish script),
flag that one line — it's the usual cause of a silently-degraded page.

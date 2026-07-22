---
name: list
description: List recent Claude Code sessions on this machine (short id, project, last active) - the candidates for crosstalk targets. Use when the user asks what sessions exist or needs to pick a target.
---

# /crosstalk:list

Read-only; works whether crosstalk is on or off.

Run `ls -t ~/.claude/projects/*/*.jsonl | head -15` and present a short table: short id (first 8 of the filename UUID), project slug (parent directory name), last-active (mtime, human-readable). Mark this session's own id. Add any aliases from `~/.claude/session-mail/names.json` next to their ids.

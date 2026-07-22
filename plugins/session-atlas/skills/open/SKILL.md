---
name: open
description: Open the living session map - hand the operator the ladder page (every session, newest first, resume commands). Use when the user asks "what's been going on", "pull up the atlas", or feels lost among sessions.
---

# /session-atlas:open

Read-only. Hand over the **ladder** page and stop — zero page content into context.

1. Read `ladder_url` from the atlas config (`~/.config/session-atlas/config.json`, or
   `$SESSION_ATLAS_CONFIG`). No config or no `ladder_url` → the page is the local file
   `~/.cache/session-atlas/html/session-ladder.html`; if it doesn't exist yet, run
   `${CLAUDE_PLUGIN_ROOT}/scripts/session-atlas` once to build it.
2. Present the URL/path as a clickable line. The secondary per-project view is
   `atlas_url` / `session-atlas.html` — mention it only if the user wants a
   project-grouped list.

**Never Read the page HTML into context** — it exists for the operator's browser.
The pages are self-serve: search, per-day jump strip, click-to-expand cards with
resume commands.

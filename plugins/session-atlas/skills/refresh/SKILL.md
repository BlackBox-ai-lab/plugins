---
name: refresh
description: Rebuild the session map pages now — summarize newly-changed sessions with this session's own model, then re-render and publish. Use when the operator asks to refresh the atlas or the pages' updated-stamp is stale.
---

# /session-atlas:refresh

Two parts: a **gist pass** (this session's model writes the "where we left off"
lines for sessions that changed) and a **render** (deterministic, ~15s). No API
key, endpoint, or model id is involved anywhere — the summarizing is done by the
model already running this session.

**Tell the operator before you start.** The render alone takes ~15 seconds and
the gist pass adds a little; say so in one line rather than going quiet, e.g.
*"Refreshing — reading the sessions that changed since the last run, then
re-rendering. About half a minute."*

## Procedure

1. **Queue the work:**
   ```
   ${CLAUDE_PLUGIN_ROOT}/scripts/session-atlas --gist-queue
   ```
   Prints `queued N session(s) -> <path>`. **If N is 0, skip to step 4.**

2. **Summarize — in a subagent, not here.** The queue file holds raw transcript
   tails; reading it into this conversation would dump session text into your
   context for no reason. Spawn one subagent (a cheap model is fine — this is
   extraction, not judgment) and give it the queue path and this task:

   > Read the JSON at `<path>`. It has an `instruction` field and an `items`
   > array; each item has `sid`, `repo`, `title`, and `tail`. Follow the
   > instruction for every item. Write `{"gists": {"<sid>": "<one-two sentence
   > gist>", ...}}` to `<out-path>` — one entry per item, no other keys. Reply
   > with just the count you wrote.

3. **Store them:**
   ```
   ${CLAUDE_PLUGIN_ROOT}/scripts/session-atlas --gist-write <out-path>
   ```
   Entries for sessions that weren't in the queue are ignored, and a session
   that changed mid-pass is simply re-queued next time.

4. **Render and publish:**
   ```
   ${CLAUDE_PLUGIN_ROOT}/scripts/session-atlas --publish
   ```
   Same slugs/URLs every time — living pages, not dated snapshots. With no
   `publish_cmd` configured, pages are still written under
   `~/.cache/session-atlas/html/`; hand over the file path instead of a URL.

5. Hand the operator the ladder URL (or path) and say how many gists were added.

**One pass is bounded** (12 sessions by default; `--limit N` to change it), so a
large backlog converges over successive refreshes rather than stalling one turn.
Sessions with a current gist are never re-summarized — the cache is keyed by
(session, last-modified).

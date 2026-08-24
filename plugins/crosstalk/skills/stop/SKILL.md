---
name: stop
description: Tear down this session's crosstalk relationships - the chatty pair (both sides) and all observe grants. Exchange logs and fleet state are kept.
disable-model-invocation: true
---

# /crosstalk:stop — the big red button (this session's relationships)

Removing permissions is always allowed. `ME=$CLAUDE_CODE_SESSION_ID`, base
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/`:

1. If `<ME>/chatty` exists: read the peer id from line 1, then delete `<ME>/chatty` and
   `<peer>/chatty` — both sides, so neither session's role reminder claims a pair afterwards.
2. Delete `<ME>/consultants` (all observe grants).
3. Confirm: no standing grants remain, so this session will not consult anyone on its own
   initiative again until the operator re-arms one. Exchange logs are kept.

This does **not** touch fleet state — `/crosstalk:release` removes a spoke, and a hub that wants
out should release its spokes first. It also does not stop native cross-session messages from
reaching this session: that is the harness's `crossSessionInbound` setting (`accept` | `hold` |
`refuse`), not crosstalk's.

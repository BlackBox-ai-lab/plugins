---
name: stop
description: Tear down this session's crosstalk relationships - pair (link + chatty, both sides) and all observe grants. Mailboxes and exchange logs are kept.
disable-model-invocation: true
---

# /crosstalk:stop — the big red button (this session's relationships)

Works whether crosstalk is on or off — removing permissions is always allowed. `ME=$CLAUDE_CODE_SESSION_ID`, base `~/.claude/session-mail/`:

1. If `<ME>/link` exists: read the peer id from line 1, then delete `<ME>/link`, `<ME>/chatty`, `<peer>/link`, `<peer>/chatty` — both sides, so neither status line shows `⇄` after its next refresh.
2. Delete `<ME>/consultants` (all observe grants).
3. Confirm: sessions separated, no standing grants remain; mailboxes and exchange logs kept. (This does NOT flip the machine-wide switch — that's `/crosstalk:off`.)

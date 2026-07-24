---
name: watch
description: Park a background wake watcher so incoming crosstalk mail can wake THIS session while it sits idle — without a human keypress. Use when the operator asks to stay wakeable/reachable while idle, or when a Stop-hook nudge reports no watcher is parked.
argument-hint: ""
---

# /crosstalk:watch — stay wakeable while idle

Closes crosstalk's one delivery gap. A *working* session drains mail at its turn end and an *idle* one on its user's next keypress — but a purely idle session with no one at the keyboard has neither, so mail used to sit until a human poked the window. A **harness-tracked background task's completion re-invokes an idle session**, so a parked watcher turns incoming mail into a wake signal: the watcher exits when mail lands, the task notification wakes the session, and the Stop hook injects the mail.

## Gate & agency (non-negotiable)

1. If `~/.claude/session-mail/ENABLED` is absent, crosstalk is OFF (the default): don't park — tell the user `/crosstalk:on` enables it, and do nothing else. (The script self-enforces this too: it refuses to park when the switch is off.)
2. Parking a watcher is maintenance of THIS session's OWN mailbox — it is **not** self-initiated messaging. It never sends, never reads another session, never contacts a peer; it only makes your own mail reach you sooner. So you MAY park one on your own initiative (e.g. when a Stop-hook nudge asks you to), and the master ENABLED switch still governs.
3. Park in the **background**, never the foreground: it sleeps for hours, so a foreground run would stall your turn.
4. Mechanics (layout, delivery paths): `${CLAUDE_PLUGIN_ROOT}/references/protocol.md`.

## Procedure

1. **Park it** with the Bash tool, `run_in_background: true` (never foreground):
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-mail-watch.sh`
   The watcher reads this session's id from `$CLAUDE_CODE_SESSION_ID`; no arguments needed.
2. **Single-instance, safe to repeat.** The script writes a pid marker (`~/.claude/session-mail/<sid>/.watcher-pid`); if a live watcher is already parked it prints `already parked` and exits, so parking twice is a harmless no-op. It costs zero tokens while parked.
3. **When mail lands**, the watcher exits and its task-completion notification wakes the session. The Stop hook injects the mail — act on it per `/crosstalk:read`, then **re-park a fresh watcher** before finishing the turn (the completed one does not restart itself). The watcher's exit message hands you the exact re-park command.
4. **24 h horizon.** If nothing arrives in 24 h the watcher exits with a "re-park" message; park a new one to stay wakeable.
5. **Self-maintaining.** When the box is empty and no live watcher is parked, the Stop hook nudges you to park one (it hands you an absolute-path command you can run directly). Seeing that nudge, park a watcher and finish your turn.

Parking a watcher does not send anything and needs no target. To stop being wakeable, simply don't re-park — there is no separate teardown; `/crosstalk:off` (which removes the master switch) also prevents any further parking.

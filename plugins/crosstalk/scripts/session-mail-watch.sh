#!/usr/bin/env bash
# Crosstalk wake watcher — makes an IDLE session wakeable by incoming mail.
#
# The gap it closes: the Stop hook delivers mail at a turn's end and the
# UserPromptSubmit hook on the next keypress — but a PURELY IDLE session has
# neither, so mail used to sit unread until a human poked the window. The
# mechanism: a HARNESS-TRACKED background task's completion re-invokes an idle
# session with nobody at the keyboard. So the model parks THIS script as a
# run_in_background Bash task before going idle; when mail lands the script
# exits, the task-completion notification wakes the session, and the Stop hook
# injects the mail. It then re-parks a fresh watcher and idles again.
#
# Park it (model, end of turn, run_in_background: true):
#   bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-mail-watch.sh
# Single-instance via a pid marker; zero tokens while parked; a 24 h horizon,
# after which it asks to be re-parked. This changes WHEN authorized mail lands,
# never WHETHER sessions talk — same safety posture as the delivery hooks, and
# gated on the same ENABLED master switch.
set -u

SID="${1:-${CLAUDE_CODE_SESSION_ID:-}}"
[ -z "$SID" ] && { echo "no session id — pass one or run from a Claude Code session"; exit 1; }
[ -f "$HOME/.claude/session-mail/ENABLED" ] || { echo "crosstalk is off (no ENABLED switch) — not parking"; exit 0; }

BOX="$HOME/.claude/session-mail/$SID/new"
MARK="$HOME/.claude/session-mail/$SID/.watcher-pid"
SELF="$(readlink -f "$0")"
mkdir -p "$BOX"

# Poll cadence and horizon (env-overridable so the test suite can run fast).
INTERVAL="${CROSSTALK_WATCH_INTERVAL:-30}"   # seconds between checks
ITERS="${CROSSTALK_WATCH_ITERS:-2880}"       # 2880 * 30 s = 24 h

# Single instance: a live watcher already parked means there is nothing to do.
if [ -f "$MARK" ]; then
  old=$(cat "$MARK" 2>/dev/null)
  if [[ "$old" =~ ^[0-9]+$ ]] && kill -0 "$old" 2>/dev/null; then
    echo "watcher already parked (pid $old) — not double-parking"; exit 0
  fi
fi
echo $$ > "$MARK"

shopt -s nullglob
for ((i = 0; i < ITERS; i++)); do
  files=("$BOX"/*.md)
  if [ ${#files[@]} -gt 0 ]; then
    rm -f "$MARK"
    echo "CROSSTALK MAIL ARRIVED (${#files[@]}) — the Stop hook injects it at this turn's end; act on it per /crosstalk:read. Then RE-PARK: run Bash with run_in_background:true: bash $SELF"
    exit 0
  fi
  sleep "$INTERVAL"
done
rm -f "$MARK"
echo "24 h quiet — RE-PARK the wake watcher: run Bash with run_in_background:true: bash $SELF"
exit 0

#!/usr/bin/env bash
# Stop hook: ACTIVE crosstalk delivery — deliver mail at the END OF A TURN,
# without waiting for the recipient's next user prompt.
#
# The Stop hook fires when Claude finishes responding (end of a turn, NOT
# session end). Returning hookSpecificOutput.additionalContext on Stop
# continues the conversation so the session can act on the delivered mail —
# so a session that is WORKING drains its mailbox at the natural end of its
# current turn, no keypress needed. Mail arriving during PURE idle is covered
# by the WAKE WATCHER (session-mail-watch.sh), a run_in_background task the
# model parks before idling: it exits when mail lands and the task-completion
# notification wakes the session. So when the box is empty this hook NUDGES any
# session that has a mailbox but no live watcher to park one — that keeps the
# pattern self-maintaining. Only an idle session with no watcher still waits
# for its user's next keypress (the UserPromptSubmit path).
#
# SAFETY (do not weaken):
#   * Gated on the same ENABLED master switch — a no-op when crosstalk is off.
#   * Only delivers mail that was explicitly SENT (operator-authorized); it never
#     makes a session self-initiate. It changes WHEN authorized mail lands, not
#     WHETHER sessions talk.
#   * Rolling-window rate limit: at most MAX_PER_WINDOW autonomous deliveries per
#     WINDOW_S per session. A back-and-forth between two working sessions is
#     bounded — past the cap, mail simply waits for a human keypress (the
#     UserPromptSubmit path, which is unbounded). A naive consecutive-delivery
#     counter would be useless here: each delivery is followed by an empty-box
#     Stop that would reset it — hence a time-window log, not a streak.
set -u

[ -f "$HOME/.claude/session-mail/ENABLED" ] || exit 0
IN=$(cat)
SID=$(jq -r '.session_id // empty' <<<"$IN" 2>/dev/null)
[ -z "$SID" ] && SID="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$SID" ] && exit 0

BOX="$HOME/.claude/session-mail/$SID/new"
LOG="$HOME/.claude/session-mail/$SID/.autodeliver-log"
WINDOW_S=300
MAX_PER_WINDOW=15

shopt -s nullglob
[ -d "$BOX" ] || exit 0
files=("$BOX"/*.md)
if [ ${#files[@]} -eq 0 ]; then
  # Nothing to deliver — but keep this session WAKEABLE while idle: if no live
  # wake watcher is parked, nudge the model to park one. Pid-gated, so a parked
  # watcher = a silent stop, and a session that just parked is never re-nudged.
  MARK="$HOME/.claude/session-mail/$SID/.watcher-pid"
  if [ -f "$MARK" ]; then
    wpid=$(cat "$MARK" 2>/dev/null)
    [[ "$wpid" =~ ^[0-9]+$ ]] && kill -0 "$wpid" 2>/dev/null && exit 0
  fi
  WATCH="$(dirname "$(readlink -f "$0")")/session-mail-watch.sh"
  jq -n --arg c "[crosstalk] No wake watcher is parked, so incoming mail can't wake this session while it's idle. Park one now — run Bash with run_in_background:true: bash $WATCH — then finish your turn. It costs zero tokens while parked; when mail lands it exits and wakes you." \
    '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$c}}'
  exit 0
fi

# Rolling-window rate limit: prune old timestamps, count recent deliveries.
now=$(date +%s)
recent=""
count=0
if [ -f "$LOG" ]; then
  while IFS= read -r ts; do
    [[ "$ts" =~ ^[0-9]+$ ]] || continue
    if [ $((now - ts)) -lt "$WINDOW_S" ]; then
      recent+="$ts"$'\n'
      count=$((count + 1))
    fi
  done < "$LOG"
fi
if [ "$count" -ge "$MAX_PER_WINDOW" ]; then
  printf '%s' "$recent" > "$LOG" 2>/dev/null   # keep the pruned log; do not deliver
  exit 0                                        # cap hit — leave mail for the next keypress
fi

DIR="$(dirname "$(readlink -f "$0")")"
ctx=$(bash "$DIR/session-mail-drain.sh" "$SID"; printf x); ctx=${ctx%x}
[ -z "$ctx" ] && exit 0

printf '%s%s\n' "$recent" "$now" > "$LOG" 2>/dev/null
jq -n --arg c "[crosstalk · auto-delivered at turn end] $ctx" \
  '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$c}}'
exit 0

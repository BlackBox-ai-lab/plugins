#!/usr/bin/env bash
# UserPromptSubmit hook: inject unread crosstalk mail (~/.claude/session-mail/<sid>/new/)
# into context on the user's next prompt, then move it to read/. Silent no-op
# when the box is empty. This is the PASSIVE delivery path (fires on a keypress);
# session-mail-stop.sh is the ACTIVE path (delivers at turn end, no keypress).
#
# The mail formatting + new/->read/ move live in session-mail-drain.sh so this
# hook and the Stop hook share ONE implementation and can never drift apart.
# Context economy: short messages inline in full; messages >2 KB inline an
# excerpt (line- AND byte-capped) with a subagent-distill pointer — see drain.
set -u
# Master switch (operator flips via /crosstalk:on|off). Default OFF: no delivery, no injection.
[ -f "$HOME/.claude/session-mail/ENABLED" ] || exit 0
IN=$(cat)
SID=$(jq -r '.session_id // empty' <<<"$IN" 2>/dev/null)
[ -z "$SID" ] && SID="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$SID" ] && exit 0

DIR="$(dirname "$(readlink -f "$0")")"
# Capture drain output preserving any trailing newline (command substitution
# would otherwise strip it): append a sentinel, then trim it back off.
ctx=$(bash "$DIR/session-mail-drain.sh" "$SID"; printf x); ctx=${ctx%x}
# Plus the standing-grants reminder (observe grants / chatty pair), if any.
consult=$(bash "$DIR/session-mail-consultants.sh" "$SID")

out="$ctx"
if [ -n "$consult" ]; then
  [ -n "$out" ] && out+=$'\n\n'
  out+="$consult"
fi

# Succession assist: if the operator is invoking a handoff and this session holds
# a crosstalk role, remind the model to put the enlist-as-successor instruction in
# the handoff doc. Composition via hook — the handoff skill itself is never modified.
BASE="$HOME/.claude/session-mail/$SID"
prompt=$(jq -r '.prompt // empty' <<<"$IN" 2>/dev/null)
if [ -n "$prompt" ] && grep -qiE 'handoff|hand off|continuation prompt' <<<"$prompt"; then
  if [ -s "$BASE/report-to" ]; then
    hub=$(head -n1 "$BASE/report-to")
    [ -n "$out" ] && out+=$'\n\n'
    out+="[crosstalk] Succession notice: this session is an enlisted spoke (hub ${hub:0:8}). If you are writing a handoff/continuation doc, include this instruction for the successor session: run /crosstalk:enlist ${hub:0:8} --succeeds $SID immediately on start (reuses the alias, writes the forward pointer, reports succession to the hub). Do NOT carry this session's history into the successor — the handoff doc alone is its context."
  elif [ -s "$BASE/roster" ]; then
    [ -n "$out" ] && out+=$'\n\n'
    out+="[crosstalk] Succession notice: this session is a HUB. If you are writing a handoff/continuation doc, instruct the successor to take over the fleet: copy this session's roster and team-state.md from ~/.claude/session-mail/$SID/ into its own session-mail dir, re-point the hub alias in names.json to itself, write this session's forward pointer to itself, and update each spoke's report-to file. Do NOT carry this session's history along."
  fi
fi

[ -z "$out" ] && exit 0

jq -n --arg c "$out" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
exit 0

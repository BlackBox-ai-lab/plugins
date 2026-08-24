#!/usr/bin/env bash
# UserPromptSubmit hook — the plugin's ONLY hook.
#
# It injects two things, both derived from this session's own crosstalk state
# under ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/<session-id>/:
#
#   1. The role/grant reminder (crosstalk-roles.sh) — so standing grants and
#      hub/spoke roles survive context compaction.
#   2. A succession notice, only when the operator's prompt is about a handoff
#      and this session holds a fleet role — so the handoff doc carries the
#      instruction that keeps the fleet wired up across a session change.
#
# Message DELIVERY is not this hook's job: Claude Code delivers cross-session
# messages natively (see the SendMessage tool), including to idle sessions.
# Silent no-op when this session has no crosstalk state — which is the default.
set -u

IN=$(cat)
SID=$(jq -r '.session_id // empty' <<<"$IN" 2>/dev/null)
[ -z "$SID" ] && SID="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$SID" ] && exit 0

DIR="$(dirname "$(readlink -f "$0")")"
out=$(bash "$DIR/crosstalk-roles.sh" "$SID")

BASE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/$SID"
prompt=$(jq -r '.prompt // empty' <<<"$IN" 2>/dev/null)
if [ -n "$prompt" ] && grep -qiE 'handoff|hand off|continuation prompt' <<<"$prompt"; then
  if [ -s "$BASE/report-to" ]; then
    hub=$(head -n1 "$BASE/report-to")
    hubname=$(sed -n '3p' "$BASE/report-to")
    addr="${hubname:-${hub:0:8}}"
    [ -n "$out" ] && out+=$'\n\n'
    out+="[crosstalk] Succession notice: this session is an enlisted spoke (hub ${hub:0:8}). If you are writing a handoff/continuation doc, include this instruction for the successor session: run /crosstalk:enlist ${addr} --succeeds ${SID} immediately on start — it reuses the alias, renames the successor so the hub's address keeps working, and reports the succession to the hub. Do NOT carry this session's history into the successor: the handoff doc alone is its context."
  elif [ -s "$BASE/roster" ]; then
    [ -n "$out" ] && out+=$'\n\n'
    out+="[crosstalk] Succession notice: this session is a HUB. If you are writing a handoff/continuation doc, instruct the successor to take over the fleet: copy roster and team-state.md from this session's crosstalk state dir into its own, run /rename with this hub's name so spokes keep addressing it, and rewrite line 1 of each spoke's report-to file with the successor's session id. Do NOT carry this session's history along."
  fi
fi

[ -z "$out" ] && exit 0

jq -n --arg c "$out" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
exit 0

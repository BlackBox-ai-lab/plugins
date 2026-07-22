#!/usr/bin/env bash
# Prints the standing-grants reminder for a session, or nothing.
#
# Two grant kinds, both operator-armed:
#   ~/.claude/session-mail/<my-id>/consultants — observe grants, one per line:
#       <peer-full-id>\t<peer-project-dir>\t<label>
#     This session MAY proactively quiet-ask those peers (read-only fork).
#   ~/.claude/session-mail/<my-id>/chatty — chatty pair marker (2 lines:
#     peer full id, peer project dir). Adds: MAY also send the pair peer short
#     delta updates about shared work.
# Absent files => no output => zero behavior change (the default).
#
# Arg $1 = full session id.
set -u

SID="${1:-}"
[ -z "$SID" ] && exit 0
BASE="$HOME/.claude/session-mail/$SID"
out=""

F="$BASE/consultants"
if [ -s "$F" ]; then
  names=""
  while IFS=$'\t' read -r pid pdir label; do
    [ -z "$pid" ] && continue
    short="${pid:0:8}"
    lbl="${label:-}"
    [ -z "$lbl" ] && [ -n "$pdir" ] && lbl="$(basename "$pdir")"
    [ -n "$lbl" ] && names+="${short} (${lbl}), " || names+="${short}, "
  done < "$F"
  names="${names%, }"
  [ -n "$names" ] && out+="[crosstalk] Authorized consultant(s) this session: ${names}. The operator drew these peer sessions into this dialogue, so you MAY proactively consult them READ-ONLY (/crosstalk:quiet-ask — a fork of their context answers) when it genuinely helps THIS work: compose a sharp question, run the fork, then tell the operator what you asked and what came back, and use it. Never proactively ASSIGN them work (no /crosstalk:request); do not consult gratuitously."
fi

C="$BASE/chatty"
if [ -s "$C" ]; then
  peer=$(head -n1 "$C")
  [ -n "$out" ] && out+=$'\n'
  out+="[crosstalk] Chatty pair active with ${peer:0:8}: you MAY proactively quiet-ask this peer AND send it short delta updates about shared work (via its mailbox). Within the pair only — never message third sessions proactively, never assign the peer work without the operator, and surface every exchange."
fi

R="$BASE/roster"
if [ -s "$R" ]; then
  fleet=""
  while IFS=$'\t' read -r alias psid _rest; do
    [ -z "$alias" ] && continue
    fleet+="${alias} (${psid:0:8}), "
  done < "$R"
  fleet="${fleet%, }"
  if [ -n "$fleet" ]; then
    [ -n "$out" ] && out+=$'\n'
    out+="[crosstalk] You are HUB for: ${fleet}. Orchestrator protocol: process incoming reports, keep team-state.md current (lives in session-mail, never in a repo), pull detail via the cheapest rung (arrived report > tail read > quiet-ask), and watch for same-repo overlap between spokes. /crosstalk:team shows the fleet."
  fi
fi

RT="$BASE/report-to"
if [ -s "$RT" ]; then
  hub=$(head -n1 "$RT")
  [ -n "$out" ] && out+=$'\n'
  out+="[crosstalk] You report to hub ${hub:0:8}: send short delta reports (<=10 lines — done / blocked / milestone / question) to its mailbox as they happen. The hub may quiet-ask this session read-only."
fi

[ -z "$out" ] && exit 0
printf '%s' "$out"
exit 0

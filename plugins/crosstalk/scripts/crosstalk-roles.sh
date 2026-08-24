#!/usr/bin/env bash
# Prints this session's crosstalk role/grant reminder, or nothing.
#
# Injected on every UserPromptSubmit (via crosstalk-prompt-hook.sh) so standing
# grants and hub/spoke roles survive context compaction — the model is told, each
# turn, exactly what it is authorized to do on its own initiative.
#
# State lives under ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/<my-session-id>/:
#   consultants — observe grants, one per line:
#       <peer-sid>\t<peer-cwd>\t<label>
#     This session MAY proactively quiet-ask those peers (read-only fork).
#   chatty      — chatty pair marker, 2 lines: peer sid, peer cwd.
#     Adds: MAY also send the pair peer short delta updates (SendMessage).
#   roster      — hub roster, one spoke per line:
#       <alias>\t<sid>\t<cwd>\t<repo-root|->\t<branch|->\t<worktree:yes/no>
#   report-to   — spoke pointer, 3 lines: hub sid, hub cwd, hub name.
# Absent files => no output => zero behavior change (the default).
#
# Arg $1 = this session's full id.
set -u

SID="${1:-}"
[ -z "$SID" ] && exit 0
BASE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/$SID"
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
  [ -n "$names" ] && out+="[crosstalk] Authorized consultant(s) this session: ${names}. The operator drew these peer sessions into this dialogue, so you MAY proactively consult them READ-ONLY (/crosstalk:quiet-ask — a throwaway fork of their context answers and their live session never sees it) when it genuinely helps THIS work: compose a sharp question, run the fork, then tell the operator what you asked and what came back, and use it. Never proactively send them a message or assign them work (no SendMessage, no /crosstalk:request); do not consult gratuitously."
fi

C="$BASE/chatty"
if [ -s "$C" ]; then
  peer=$(head -n1 "$C")
  [ -n "$out" ] && out+=$'\n'
  out+="[crosstalk] Chatty pair active with ${peer:0:8}: you MAY proactively quiet-ask this peer AND send it short delta updates about shared work with the SendMessage tool, addressed to its session name. Within the pair only — never message third sessions proactively, never assign the peer work without the operator, and surface every exchange."
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
    out+="[crosstalk] You are HUB for: ${fleet}. Orchestrator protocol: spokes report to you with the SendMessage tool — process each report, keep team-state.md current (it lives in the crosstalk state dir, never in a repo), pull extra detail via the cheapest rung (arrived report > tail read > quiet-ask), and watch for same-repo overlap between spokes. /crosstalk:team shows the fleet."
  fi
fi

RT="$BASE/report-to"
if [ -s "$RT" ]; then
  hub=$(head -n1 "$RT")
  hubname=$(sed -n '3p' "$RT")
  addr="${hubname:-${hub:0:8}}"
  [ -n "$out" ] && out+=$'\n'
  out+="[crosstalk] You report to hub ${hub:0:8}: send short delta reports (<=10 lines — done / blocked / milestone / question) as they happen, using the SendMessage tool addressed to \"${addr}\". The hub may quiet-ask this session read-only."
fi

[ -z "$out" ] && exit 0
printf '%s' "$out"
exit 0

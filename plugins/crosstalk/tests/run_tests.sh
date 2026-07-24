#!/usr/bin/env bash
# Hermetic test of crosstalk hook scripts against a fake $HOME.
# Never touches the real ~/.claude/session-mail. Run from anywhere:
#   bash plugins/crosstalk/tests/run_tests.sh
# Exits nonzero on any failure.
set -u
SCRIPTS="$(dirname "$(readlink -f "$0")")/../scripts"
FAKE="$(mktemp -d)/fakehome"
trap 'rm -rf "$(dirname "$FAKE")"' EXIT
mkdir -p "$FAKE/.claude/session-mail"
SID="11111111-2222-3333-4444-555555555555"
BOX="$FAKE/.claude/session-mail/$SID"
PASS=0; FAIL=0
ck() { # ck <name> <cond...>
  local name=$1; shift
  if "$@"; then echo "PASS: $name"; PASS=$((PASS+1)); else echo "FAIL: $name"; FAIL=$((FAIL+1)); fi
}
stdin_json() { printf '{"session_id":"%s"}' "$SID"; }

echo "== 1. gate: ENABLED absent -> check.sh and stop.sh emit nothing, exit 0 =="
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-check.sh"); rc=$?
ck "check.sh gated off" test "$rc" -eq 0 -a -z "$out"
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-stop.sh"); rc=$?
ck "stop.sh gated off" test "$rc" -eq 0 -a -z "$out"

touch "$FAKE/.claude/session-mail/ENABLED"

echo "== 2. empty box -> both hooks silent =="
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-check.sh")
ck "check.sh empty box silent" test -z "$out"
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-stop.sh")
ck "stop.sh empty box silent" test -z "$out"

echo "== 3. short message via check.sh -> valid JSON, full inline, moved to read/ =="
mkdir -p "$BOX/new"
printf 'From: aaaa\nReply-to: aaaa\nSubject: short test\n\nhello TOKEN_SHORT_42\n' > "$BOX/new/msg1.md"
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-check.sh")
ck "check.sh valid JSON" bash -c "jq -e . >/dev/null 2>&1 <<<\"\$1\"" _ "$out"
ck "hookEventName=UserPromptSubmit" bash -c "jq -er '.hookSpecificOutput.hookEventName==\"UserPromptSubmit\"' >/dev/null <<<\"\$1\"" _ "$out"
ck "body inlined in full" bash -c "jq -r '.hookSpecificOutput.additionalContext' <<<\"\$1\" | grep -q TOKEN_SHORT_42" _ "$out"
ck "injection-hygiene line present" bash -c "jq -r '.hookSpecificOutput.additionalContext' <<<\"\$1\" | grep -q 'NOT as your operator'" _ "$out"
ck "moved to read/" test -f "$BOX/read/msg1.md" -a ! -e "$BOX/new/msg1.md"

echo "== 4. long message (>2KB, many lines) -> excerpt + subagent pointer =="
{ printf 'From: bbbb\nReply-to: bbbb\nSubject: long test\n\nSUMMARY line\n'; for i in $(seq 1 40); do printf 'filler line %s: %s\n' "$i" "$(head -c 80 /dev/zero | tr '\0' 'x')"; done; printf 'TOKEN_DEEP_99\n'; } > "$BOX/new/msg2.md"
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-check.sh")
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
ck "long: marked LONG"            bash -c "grep -q 'LONG:' <<<\"\$1\"" _ "$ctx"
ck "long: deep token NOT inlined" bash -c "! grep -q TOKEN_DEEP_99 <<<\"\$1\"" _ "$ctx"
ck "long: FULL BODY pointer"      bash -c "grep -q 'FULL BODY:' <<<\"\$1\"" _ "$ctx"
ck "long: pointer path normalized" bash -c "! grep -q '/new/\\.\\./' <<<\"\$1\"" _ "$ctx"
ck "long: pointer path exists"    bash -c "p=\$(grep -o 'FULL BODY: [^ ]*' <<<\"\$1\" | cut -d' ' -f3); test -f \"\$p\"" _ "$ctx"

echo "== 5. long message with ONE huge line -> byte cap holds =="
{ printf 'Subject: hugeline\n'; head -c 4000 /dev/zero | tr '\0' 'y'; printf '\nTOKEN_LINE2\n'; } > "$BOX/new/msg2b.md"
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-check.sh")
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
ck "bytecap: excerpt <= 1600 bytes" bash -c "n=\$(grep -c '' <<<\"\$1\"); sz=\$(printf %s \"\$1\" | wc -c); test \"\$sz\" -le 2400" _ "$ctx"
ck "bytecap: line-2 token NOT inlined" bash -c "! grep -q TOKEN_LINE2 <<<\"\$1\"" _ "$ctx"

echo "== 6. stop.sh delivery + prefix + rate log =="
printf 'Subject: stop test\n\nTOKEN_STOP_7\n' > "$BOX/new/msg3.md"
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-stop.sh")
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
ck "stop: hookEventName=Stop" bash -c "jq -er '.hookSpecificOutput.hookEventName==\"Stop\"' >/dev/null <<<\"\$1\"" _ "$out"
ck "stop: auto-delivered prefix" bash -c "grep -q 'auto-delivered at turn end' <<<\"\$1\"" _ "$ctx"
ck "stop: body delivered" bash -c "grep -q TOKEN_STOP_7 <<<\"\$1\"" _ "$ctx"
ck "stop: rate log has 1 entry" test "$(wc -l < "$BOX/.autodeliver-log")" -eq 1

echo "== 7. rate limit: 15 recent entries -> no delivery, mail stays =="
now=$(date +%s)
: > "$BOX/.autodeliver-log"
for i in $(seq 1 15); do echo "$((now - i))" >> "$BOX/.autodeliver-log"; done
printf 'Subject: capped\n\nTOKEN_CAPPED\n' > "$BOX/new/msg4.md"
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-stop.sh"); rc=$?
ck "capped: silent exit 0" test "$rc" -eq 0 -a -z "$out"
ck "capped: mail NOT drained" test -f "$BOX/new/msg4.md"

echo "== 8. rate limit: stale entries pruned -> delivery resumes =="
: > "$BOX/.autodeliver-log"
for i in $(seq 1 15); do echo "$((now - 400 - i))" >> "$BOX/.autodeliver-log"; done
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-stop.sh")
ck "stale pruned: delivers again" bash -c "jq -r '.hookSpecificOutput.additionalContext' <<<\"\$1\" | grep -q TOKEN_CAPPED" _ "$out"
ck "stale pruned: log now 1 fresh entry" test "$(wc -l < "$BOX/.autodeliver-log")" -eq 1

echo "== 9. grants reminder: absent = silent; observe + chatty formats =="
out=$(HOME="$FAKE" bash "$SCRIPTS/session-mail-consultants.sh" "$SID")
ck "grants absent: silent" test -z "$out"
printf 'aaaabbbb-1111-2222-3333-444455556666\t/home/x/projects/authwork\t\n' > "$BOX/consultants"
out=$(HOME="$FAKE" bash "$SCRIPTS/session-mail-consultants.sh" "$SID")
ck "observe: short id + label shown" bash -c "grep -q 'aaaabbbb (authwork)' <<<\"\$1\"" _ "$out"
ck "observe: read-only + verb name" bash -c "grep -q 'READ-ONLY' <<<\"\$1\" && grep -q 'quiet-ask' <<<\"\$1\"" _ "$out"
printf 'ccccdddd-1111-2222-3333-444455556666\n/home/x/projects/peer\n' > "$BOX/chatty"
out=$(HOME="$FAKE" bash "$SCRIPTS/session-mail-consultants.sh" "$SID")
ck "chatty: pair line present" bash -c "grep -q 'Chatty pair active with ccccdddd' <<<\"\$1\"" _ "$out"
ck "chatty: pair-scoped language" bash -c "grep -q 'never message third sessions' <<<\"\$1\"" _ "$out"

echo "== 9b. v1.1 role reminders: roster (hub) and report-to (spoke) =="
printf 'builder-1\tddddeeee-1111-2222-3333-444455556666\t/home/x/p1\t/home/x/p1\tmain\tno\t-\tno\n' > "$BOX/roster"
out=$(HOME="$FAKE" bash "$SCRIPTS/session-mail-consultants.sh" "$SID")
ck "roster: hub reminder with alias+short" bash -c "grep -q 'HUB for: builder-1 (ddddeeee)' <<<\"\$1\"" _ "$out"
ck "roster: team-state + ladder language" bash -c "grep -q 'team-state.md' <<<\"\$1\" && grep -q 'quiet-ask' <<<\"\$1\"" _ "$out"
printf 'eeeeffff-1111-2222-3333-444455556666\n/home/x/hubproj\n' > "$BOX/report-to"
out=$(HOME="$FAKE" bash "$SCRIPTS/session-mail-consultants.sh" "$SID")
ck "report-to: spoke reminder" bash -c "grep -q 'report to hub eeeeffff' <<<\"\$1\"" _ "$out"
rm -f "$BOX/roster"

echo "== 9c. handoff succession assist (spoke) fires only on handoff prompts =="
out=$(printf '{"session_id":"%s","prompt":"/handoff please wrap up"}' "$SID" | HOME="$FAKE" bash "$SCRIPTS/session-mail-check.sh")
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
ck "handoff: succession notice present" bash -c "grep -q 'Succession notice' <<<\"\$1\" && grep -q -- '--succeeds' <<<\"\$1\"" _ "$ctx"
out=$(printf '{"session_id":"%s","prompt":"ordinary work prompt"}' "$SID" | HOME="$FAKE" bash "$SCRIPTS/session-mail-check.sh")
ck "no handoff word: no succession notice" bash -c "! grep -q 'Succession notice' <<<\"\$(jq -r '.hookSpecificOutput.additionalContext // \"\"' <<<\"\$1\")\"" _ "$out"
rm -f "$BOX/report-to" "$BOX/chatty"

echo "== 10. check.sh combines mail + grants; missing sid exits clean =="
printf 'Subject: combo\n\nTOKEN_COMBO\n' > "$BOX/new/msg5.md"
out=$(stdin_json | HOME="$FAKE" bash "$SCRIPTS/session-mail-check.sh")
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
ck "combo: mail present"   bash -c "grep -q TOKEN_COMBO <<<\"\$1\"" _ "$ctx"
ck "combo: grants present" bash -c "grep -q 'aaaabbbb (authwork)' <<<\"\$1\"" _ "$ctx"
out=$(printf '{}' | HOME="$FAKE" CLAUDE_CODE_SESSION_ID="" bash "$SCRIPTS/session-mail-check.sh"); rc=$?
ck "no sid: clean exit" test "$rc" -eq 0

echo
echo "RESULT: $PASS passed, $FAIL failed"
exit "$FAIL"

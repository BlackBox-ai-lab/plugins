#!/usr/bin/env bash
# Hermetic test of the crosstalk scripts against a fake CLAUDE_CONFIG_DIR and a
# fake HOME. Never reads or writes real session state. Run from anywhere:
#   bash plugins/crosstalk/tests/run_tests.sh
# Exits nonzero on any failure.
set -u
SCRIPTS="$(dirname "$(readlink -f "$0")")/../scripts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CFG="$TMP/cfg"
FAKEHOME="$TMP/home"
mkdir -p "$CFG/sessions" "$CFG/projects/-home-x-proj" "$CFG/crosstalk" "$FAKEHOME"

# Session ids used throughout (fixed, so assertions can name them).
SID_ME="11111111-2222-3333-4444-555555555555"      # "this" session in the hook tests
SID_A="aaaa1111-2222-3333-4444-555555555555"       # live, named alpha-builder
SID_B="bbbb1111-2222-3333-4444-555555555555"       # live, named beta-builder
SID_DEAD="cccc1111-2222-3333-4444-555555555555"    # registry entry with a dead pid
SID_D1="dddd1111-2222-3333-4444-000000000001"      # two live sessions sharing a
SID_D2="dddd1111-2222-3333-4444-000000000002"      # short-id prefix -> ambiguous
SID_CLOSED="eeee1111-2222-3333-4444-555555555555"  # no registry entry, transcript only
DEAD_PID=4194305   # above the default pid_max: cannot exist

PASS=0; FAIL=0
ck() { # ck <name> <cond...>
  local name=$1; shift
  if "$@"; then echo "PASS: $name"; PASS=$((PASS+1)); else echo "FAIL: $name"; FAIL=$((FAIL+1)); fi
}
reg() { # reg <file-stem> <pid> <sid> <cwd> <name> <status>
  printf '{"pid":%s,"sessionId":"%s","cwd":"%s","name":"%s","nameSource":"rename","status":"%s","kind":"interactive","version":"2.1.241","messagingSocketPath":"/run/user/0/cc-socks/%s.sock","startedAt":1,"updatedAt":2}\n' \
    "$2" "$3" "$4" "$5" "$6" "$2" > "$CFG/sessions/$1.json"
}
run() { CLAUDE_CONFIG_DIR="$CFG" HOME="$FAKEHOME" "$@"; }

# Live entries carry this test process's pid, which is by definition alive.
# (Real registry files are named <pid>.json; the resolver reads the pid from the
# contents, so the stems here only need to be distinct.)
reg alpha "$$"        "$SID_A"    "/home/x/alpha" "alpha-builder" "busy"
reg beta  "$$"        "$SID_B"    "/home/x/beta"  "beta-builder"  "idle"
reg ghost "$DEAD_PID" "$SID_DEAD" "/home/x/ghost" "ghost-session" "busy"
reg d1    "$$"        "$SID_D1"   "/home/x/d1"    "dupe-one"      "busy"
reg d2    "$$"        "$SID_D2"   "/home/x/d2"    "dupe-two"      "idle"
# A closed session: transcript only, no registry entry.
printf '{"type":"user","cwd":"/home/x/closedproj","message":{"role":"user","content":"hi"}}\n' \
  > "$CFG/projects/-home-x-proj/$SID_CLOSED.jsonl"
# Junk file in the registry: must not break the scan.
printf 'not json at all\n' > "$CFG/sessions/junk.json"

echo "== 1. resolver: exact name match =="
out=$(run bash "$SCRIPTS/crosstalk-resolve.sh" alpha-builder 2>/dev/null); rc=$?
ck "name: exit 0"        test "$rc" -eq 0
ck "name: sid returned"  test "$(cut -f1 <<<"$out")" = "$SID_A"
ck "name: cwd returned"  test "$(cut -f2 <<<"$out")" = "/home/x/alpha"
ck "name: name returned" test "$(cut -f3 <<<"$out")" = "alpha-builder"
ck "name: status busy"   test "$(cut -f4 <<<"$out")" = "busy"

echo "== 2. resolver: 8-char short id and full uuid =="
out=$(run bash "$SCRIPTS/crosstalk-resolve.sh" bbbb1111 2>/dev/null); rc=$?
ck "short id: exit 0"     test "$rc" -eq 0
ck "short id: right sid"  test "$(cut -f1 <<<"$out")" = "$SID_B"
ck "short id: status"     test "$(cut -f4 <<<"$out")" = "idle"
out=$(run bash "$SCRIPTS/crosstalk-resolve.sh" "$SID_B" 2>/dev/null)
ck "full uuid: right sid" test "$(cut -f1 <<<"$out")" = "$SID_B"

echo "== 3. resolver: ambiguous short id -> exit 1 + candidates on stderr =="
err=$(run bash "$SCRIPTS/crosstalk-resolve.sh" dddd1111 2>&1 >/dev/null); rc=$?
ck "ambiguous: exit 1"          test "$rc" -eq 1
ck "ambiguous: says ambiguous"  bash -c "grep -qi ambiguous <<<\"\$1\"" _ "$err"
ck "ambiguous: lists both"      bash -c "grep -q 'dupe-one' <<<\"\$1\" && grep -q 'dupe-two' <<<\"\$1\"" _ "$err"
out=$(run bash "$SCRIPTS/crosstalk-resolve.sh" dddd1111 2>/dev/null)
ck "ambiguous: stdout empty"    test -z "$out"

echo "== 4. resolver: own session id / own name -> exit 2, silent =="
out=$(CLAUDE_CODE_SESSION_ID="$SID_A" run bash "$SCRIPTS/crosstalk-resolve.sh" alpha-builder 2>/dev/null); rc=$?
ck "self by name: exit 2"   test "$rc" -eq 2
ck "self by name: silent"   test -z "$out"
out=$(CLAUDE_CODE_SESSION_ID="$SID_A" run bash "$SCRIPTS/crosstalk-resolve.sh" aaaa1111 2>/dev/null); rc=$?
ck "self by short id: exit 2" test "$rc" -eq 2

echo "== 5. resolver: registry entry with a dead pid is skipped =="
out=$(run bash "$SCRIPTS/crosstalk-resolve.sh" ghost-session 2>/dev/null); rc=$?
ck "dead pid: not resolved (exit 1)" test "$rc" -eq 1
ck "dead pid: nothing on stdout"     test -z "$out"
out=$(run bash "$SCRIPTS/crosstalk-resolve.sh" cccc1111 2>/dev/null); rc=$?
ck "dead pid: short id not resolved" test "$rc" -eq 1

echo "== 6. resolver: closed session resolves from its transcript =="
out=$(run bash "$SCRIPTS/crosstalk-resolve.sh" eeee1111 2>/dev/null); rc=$?
ck "closed: exit 0"       test "$rc" -eq 0
ck "closed: sid"          test "$(cut -f1 <<<"$out")" = "$SID_CLOSED"
ck "closed: cwd from jsonl" test "$(cut -f2 <<<"$out")" = "/home/x/closedproj"
ck "closed: status closed"  test "$(cut -f4 <<<"$out")" = "closed"

echo "== 7. resolver: no match at all -> exit 1 with a pointer =="
err=$(run bash "$SCRIPTS/crosstalk-resolve.sh" nobody-here 2>&1 >/dev/null); rc=$?
ck "missing: exit 1"        test "$rc" -eq 1
ck "missing: suggests list" bash -c "grep -q 'crosstalk:list' <<<\"\$1\"" _ "$err"

echo "== 8. roles reminder: absent state = silent =="
out=$(run bash "$SCRIPTS/crosstalk-roles.sh" "$SID_ME"); rc=$?
ck "roles: silent by default" test "$rc" -eq 0 -a -z "$out"
out=$(run bash "$SCRIPTS/crosstalk-roles.sh"); rc=$?
ck "roles: no sid arg is a clean no-op" test "$rc" -eq 0 -a -z "$out"

BOX="$CFG/crosstalk/$SID_ME"
mkdir -p "$BOX"

echo "== 9. roles reminder: observe grants =="
printf 'aaaabbbb-1111-2222-3333-444455556666\t/home/x/authwork\t\n' > "$BOX/consultants"
out=$(run bash "$SCRIPTS/crosstalk-roles.sh" "$SID_ME")
ck "observe: short id + label"  bash -c "grep -q 'aaaabbbb (authwork)' <<<\"\$1\"" _ "$out"
ck "observe: read-only + verb"  bash -c "grep -q 'READ-ONLY' <<<\"\$1\" && grep -q 'quiet-ask' <<<\"\$1\"" _ "$out"
ck "observe: no proactive send" bash -c "grep -q 'no SendMessage' <<<\"\$1\"" _ "$out"

echo "== 10. roles reminder: chatty pair =="
printf 'ccccdddd-1111-2222-3333-444455556666\n/home/x/peer\n' > "$BOX/chatty"
out=$(run bash "$SCRIPTS/crosstalk-roles.sh" "$SID_ME")
ck "chatty: pair line"        bash -c "grep -q 'Chatty pair active with ccccdddd' <<<\"\$1\"" _ "$out"
ck "chatty: SendMessage named" bash -c "grep -q 'SendMessage' <<<\"\$1\"" _ "$out"
ck "chatty: pair-scoped"      bash -c "grep -q 'never message third sessions' <<<\"\$1\"" _ "$out"

echo "== 11. roles reminder: hub roster =="
printf 'builder-1\tddddeeee-1111-2222-3333-444455556666\t/home/x/p1\t/home/x/p1\tmain\tno\n' > "$BOX/roster"
out=$(run bash "$SCRIPTS/crosstalk-roles.sh" "$SID_ME")
ck "roster: hub + alias/short"  bash -c "grep -q 'HUB for: builder-1 (ddddeeee)' <<<\"\$1\"" _ "$out"
ck "roster: team-state + ladder" bash -c "grep -q 'team-state.md' <<<\"\$1\" && grep -q 'quiet-ask' <<<\"\$1\"" _ "$out"
ck "roster: SendMessage named"   bash -c "grep -q 'SendMessage' <<<\"\$1\"" _ "$out"
rm -f "$BOX/roster"

echo "== 12. roles reminder: spoke report-to (3rd line = hub name) =="
printf 'eeeeffff-1111-2222-3333-444455556666\n/home/x/hubproj\norchestrator\n' > "$BOX/report-to"
out=$(run bash "$SCRIPTS/crosstalk-roles.sh" "$SID_ME")
ck "report-to: hub short id"    bash -c "grep -q 'report to hub eeeeffff' <<<\"\$1\"" _ "$out"
ck "report-to: SendMessage"     bash -c "grep -q 'SendMessage' <<<\"\$1\"" _ "$out"
ck "report-to: addressed by name" bash -c "grep -q '\"orchestrator\"' <<<\"\$1\"" _ "$out"
# Without a name line it falls back to the hub's short id.
printf 'eeeeffff-1111-2222-3333-444455556666\n/home/x/hubproj\n' > "$BOX/report-to.noname"
mv "$BOX/report-to" "$BOX/report-to.named"; mv "$BOX/report-to.noname" "$BOX/report-to"
out=$(run bash "$SCRIPTS/crosstalk-roles.sh" "$SID_ME")
ck "report-to: falls back to short id" bash -c "grep -q '\"eeeeffff\"' <<<\"\$1\"" _ "$out"
mv "$BOX/report-to.named" "$BOX/report-to"

echo "== 13. prompt hook: valid JSON wrapping the reminder =="
out=$(printf '{"session_id":"%s","prompt":"ordinary work prompt"}' "$SID_ME" | run bash "$SCRIPTS/crosstalk-prompt-hook.sh")
ck "hook: valid JSON"       bash -c "jq -e . >/dev/null 2>&1 <<<\"\$1\"" _ "$out"
ck "hook: event name"       bash -c "jq -er '.hookSpecificOutput.hookEventName==\"UserPromptSubmit\"' >/dev/null <<<\"\$1\"" _ "$out"
ck "hook: carries reminder" bash -c "jq -r '.hookSpecificOutput.additionalContext' <<<\"\$1\" | grep -q 'Chatty pair active'" _ "$out"
ck "hook: no succession on an ordinary prompt" \
  bash -c "! jq -r '.hookSpecificOutput.additionalContext' <<<\"\$1\" | grep -q 'Succession notice'" _ "$out"

echo "== 14. prompt hook: succession notice fires only on handoff prompts =="
out=$(printf '{"session_id":"%s","prompt":"/handoff please wrap up"}' "$SID_ME" | run bash "$SCRIPTS/crosstalk-prompt-hook.sh")
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
ck "handoff: notice present"   bash -c "grep -q 'Succession notice' <<<\"\$1\"" _ "$ctx"
ck "handoff: names --succeeds" bash -c "grep -q -- '--succeeds' <<<\"\$1\"" _ "$ctx"
ck "handoff: addresses the hub by name" bash -c "grep -q 'enlist orchestrator' <<<\"\$1\"" _ "$ctx"
rm -f "$BOX/report-to"
printf 'builder-1\tddddeeee-1111-2222-3333-444455556666\t/home/x/p1\t/home/x/p1\tmain\tno\n' > "$BOX/roster"
out=$(printf '{"session_id":"%s","prompt":"write a handoff doc"}' "$SID_ME" | run bash "$SCRIPTS/crosstalk-prompt-hook.sh")
ctx=$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")
ck "handoff (hub): hub succession notice" bash -c "grep -q 'this session is a HUB' <<<\"\$1\"" _ "$ctx"
ck "handoff (hub): tells successor to /rename" bash -c "grep -q '/rename' <<<\"\$1\"" _ "$ctx"

echo "== 15. prompt hook: no state and no session id are both clean no-ops =="
out=$(printf '{"session_id":"%s","prompt":"hello"}' "99999999-0000-0000-0000-000000000000" | run bash "$SCRIPTS/crosstalk-prompt-hook.sh"); rc=$?
ck "hook: unknown session silent" test "$rc" -eq 0 -a -z "$out"
out=$(printf '{}' | CLAUDE_CODE_SESSION_ID="" run bash "$SCRIPTS/crosstalk-prompt-hook.sh"); rc=$?
ck "hook: no session id, clean exit" test "$rc" -eq 0 -a -z "$out"

echo "== 16. nothing was written outside the fake config dir =="
ck "no legacy session-mail dir created" test ! -e "$FAKEHOME/.claude/session-mail"
ck "resolver wrote nothing" test ! -e "$CFG/crosstalk/$SID_A"

echo
echo "RESULT: $PASS passed, $FAIL failed"
exit "$FAIL"

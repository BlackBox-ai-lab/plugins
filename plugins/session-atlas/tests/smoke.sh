#!/bin/bash
# Smoke test: fixture projects tree -> pages render, --find and --resolve hit.
# No network, no gists, no config beyond the fixture's. Run from anywhere.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$HERE/scripts/session-atlas"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SID="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
PROJ="$TMP/home/.claude/projects/-data-fixture-repo"
mkdir -p "$PROJ" "$TMP/home/.config/session-atlas"

{ # a minimal transcript: cwd + a user ask + an assistant reply, padded >2KB
  printf '{"type":"user","cwd":"/data/fixture-repo","timestamp":"2026-07-22T10:00:00Z","message":{"content":"build the frobnicator template"}}\n'
  printf '{"type":"assistant","message":{"content":[{"type":"text","text":"built the frobnicator template with two scripts"}]}}\n'
  for i in $(seq 40); do
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"padding line %d to clear the small-file filter ................................"}]}}\n' "$i"
  done
} > "$PROJ/$SID.jsonl"

cat > "$TMP/config.json" <<EOF
{"accounts":[{"label":"t1","launcher":"claude","projects":"$TMP/home/.claude/projects"}]}
EOF

export HOME="$TMP/home"
export SESSION_ATLAS_CONFIG="$TMP/config.json"

python3 "$ENGINE" >/dev/null
test -s "$TMP/home/.cache/session-atlas/html/session-ladder.html"
test -s "$TMP/home/.cache/session-atlas/html/session-atlas.html"
grep -q "fixture-repo" "$TMP/home/.cache/session-atlas/html/session-ladder.html"

python3 "$ENGINE" --find "frobnicator template" | grep -q "claude --resume $SID"
python3 "$ENGINE" --resolve aaaaaaaa | grep -Pq "^$SID\tt1\tclaude\t/data/fixture-repo\t-"
if python3 "$ENGINE" --import aaaaaaaa 2>/dev/null; then
  echo "FAIL: import should refuse with a single account"; exit 1
fi

# a session with no summarizable tail must never occupy a queue slot
EMPTY="bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
{ printf '{"type":"user","cwd":"/data/fixture-repo","timestamp":"2026-07-22T10:00:00Z","isMeta":true,"message":{"content":"<meta only>"}}\n'
  for i in $(seq 40); do
    printf '{"type":"system","note":"padding %%d to clear the small-file filter ................................"}\n' "$i"
  done
} > "$PROJ/$EMPTY.jsonl"
python3 "$ENGINE" --gist-queue --limit 5 | grep -q "queued 1 session"   # still 1, not 2
python3 -c "
import json; q=json.load(open('$TMP/home/.cache/session-atlas/gist-queue.json'))
assert [i['sid'] for i in q['items']]==['$SID'], q
"
rm -f "$PROJ/$EMPTY.jsonl"

# gist round trip: queue -> write -> rendered into the page (no network, no key)
python3 "$ENGINE" --gist-queue --limit 5 | grep -q "queued 1 session"
python3 -c "
import json; q=json.load(open('$TMP/home/.cache/session-atlas/gist-queue.json'))
assert q['instruction'] and len(q['items'])==1, q
assert q['items'][0]['sid']=='$SID' and q['items'][0]['tail'], q
"
cat > "$TMP/gists.json" <<GEOF
{"gists": {"$SID": "Smoke-test gist line.", "bogus-sid-not-queued": "ignore me"}}
GEOF
python3 "$ENGINE" --gist-write "$TMP/gists.json" | grep -q "wrote 1 gist"
python3 -c "
import json; c=json.load(open('$TMP/home/.cache/session-atlas/summaries.json'))
assert c['$SID']['gist']=='Smoke-test gist line.', c
assert 'bogus-sid-not-queued' not in c, 'unqueued sid must be rejected'
"
python3 "$ENGINE" >/dev/null
grep -q "Smoke-test gist line." "$TMP/home/.cache/session-atlas/html/session-ladder.html"

# ai-title: a session the operator never renamed wears the title Claude
# generated, not its opening prompt — and the LAST such record wins, because
# the title is rewritten as a session evolves.
TITLED="cccccccc-dddd-eeee-ffff-000000000000"
{ printf '{"type":"user","cwd":"/data/fixture-repo","timestamp":"2026-07-22T11:00:00Z","message":{"content":"open question about widgets"}}\n'
  printf '{"type":"ai-title","aiTitle":"First guess at a title"}\n'
  printf '{"type":"assistant","message":{"content":[{"type":"text","text":"answering about widgets"}]}}\n'
  printf '{"type":"ai-title","aiTitle":"Widget subsystem rewrite"}\n'
  for i in $(seq 40); do
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"padding line %d to clear the small-file filter ................................"}]}}\n' "$i"
  done
} > "$PROJ/$TITLED.jsonl"

python3 "$ENGINE" >/dev/null
for PAGE in session-ladder session-atlas; do
  P="$TMP/home/.cache/session-atlas/html/$PAGE.html"
  if ! grep -q "Widget subsystem rewrite" "$P"; then
    echo "FAIL: $PAGE lacks the ai-title"; exit 1
  fi
  if grep -q "First guess at a title" "$P"; then
    echo "FAIL: $PAGE shows a superseded ai-title"; exit 1
  fi
done
# the opening prompt is not lost — it moves off the title line, not off the page
grep -q "open question about widgets" "$TMP/home/.cache/session-atlas/html/session-atlas.html"

# the title is searchable, and carries the topic line of --find / --resolve
python3 "$ENGINE" --find "widget subsystem" | grep -q "claude --resume $TITLED"
python3 "$ENGINE" --resolve cccccccc | grep -q "Widget subsystem rewrite"

# an operator rename still outranks the generated title: `name` means "the
# operator named this", and ai-title must never be folded into it
RENAMED="dddddddd-eeee-ffff-0000-111111111111"
{ printf '{"type":"user","cwd":"/data/fixture-repo","timestamp":"2026-07-22T12:00:00Z","message":{"content":"third fixture session"}}\n'
  printf '{"type":"ai-title","aiTitle":"Generated title loses"}\n'
  printf '{"type":"custom-title","customTitle":"Operator rename wins"}\n'
  for i in $(seq 40); do
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"padding line %d to clear the small-file filter ................................"}]}}\n' "$i"
  done
} > "$PROJ/$RENAMED.jsonl"
python3 "$ENGINE" --resolve dddddddd | grep -q "Operator rename wins"

# --- the SQLite index -------------------------------------------------------
test -s "$TMP/home/.cache/session-atlas/index.db"

# --resolve TSV contract: exactly 7 tab-separated fields per row
python3 "$ENGINE" --resolve aaaaaaaa | python3 -c "
import sys; rows=[l.rstrip('\n').split('\t') for l in sys.stdin]
assert rows and all(len(r)==7 for r in rows), rows
assert rows[0][4] in ('running','-') and len(rows[0][5])==19, rows"

# full coverage: an OLD session behind 401 newer ones is still found, by id
# and by topic (the old engine scanned only the newest 400, within 90 days)
OLD="eeeeeeee-0000-1111-2222-333333333333"
{ printf '{"type":"user","cwd":"/data/old-repo","timestamp":"2026-05-01T10:00:00Z","message":{"content":"archaeology of the zanzibar ledger"}}\n'
  for i in $(seq 40); do
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"padding line %d to clear the small-file filter ................................"}]}}\n' "$i"
  done
} > "$PROJ/$OLD.jsonl"
touch -d "100 days ago" "$PROJ/$OLD.jsonl"
python3 - "$PROJ" <<'PY'
import os, sys
pad = "".join('{"type":"assistant","message":{"content":[{"type":"text","text":"filler %d ........................................................"}]}}\n' % i for i in range(40))
for i in range(401):
    sid = "f%07x-0000-4000-8000-%012x" % (i, i)
    with open(os.path.join(sys.argv[1], sid + ".jsonl"), "w") as fh:
        fh.write('{"type":"user","cwd":"/data/filler","timestamp":"2026-07-22T10:00:00Z","message":{"content":"filler session %d"}}\n' % i)
        fh.write(pad)
PY
python3 "$ENGINE" --resolve eeeeeeee | grep -q "^$OLD	t1	claude	/data/old-repo	"
python3 "$ENGINE" --resolve "zanzibar ledger" | head -1 | grep -q "^$OLD	"
python3 "$ENGINE" --find "zanzibar" | grep -q "claude --resume $OLD"

# incremental: a changed transcript is re-read (a late rename shows up), a
# deleted one leaves the index
printf '{"type":"custom-title","customTitle":"Zanzibar renamed late"}\n' >> "$PROJ/$OLD.jsonl"
python3 "$ENGINE" --resolve eeeeeeee | grep -q "Zanzibar renamed late"
rm -f "$PROJ"/f*-0000-4000-8000-*.jsonl "$PROJ/$OLD.jsonl"
if python3 "$ENGINE" --resolve eeeeeeee 2>/dev/null; then
  echo "FAIL: a deleted transcript is still resolvable"; exit 1
fi

# bounded reads: a transcript far larger than both windows is indexed from its
# head (first prompt) and tail (current title) without reading the middle
BIG="99999999-aaaa-bbbb-cccc-dddddddddddd"
python3 - "$PROJ/$BIG.jsonl" <<'PY'
import sys
with open(sys.argv[1], "w") as fh:
    fh.write('{"type":"user","cwd":"/data/big-repo","timestamp":"2026-07-22T10:00:00Z","message":{"content":"quokka migration kickoff"}}\n')
    fh.write('{"type":"ai-title","aiTitle":"Early guess"}\n')
    for i in range(6000):  # ~1.4 MB of middle
        fh.write('{"type":"assistant","message":{"content":[{"type":"text","text":"middle %d ' % i + "m" * 200 + '"}]}}\n')
    fh.write('{"type":"ai-title","aiTitle":"Quokka migration finished"}\n')
PY
python3 "$ENGINE" --resolve 99999999 | grep -q "Quokka migration finished"
python3 "$ENGINE" --resolve "quokka kickoff" | head -1 | grep -q "^$BIG	"

# a short all-letter hex WORD that is no session's id falls through to topic search
python3 "$ENGINE" --resolve "deadbee" 2>/dev/null && { echo "FAIL: deadbee matched"; exit 1; }
printf '{"type":"custom-title","customTitle":"facade menu rework"}\n' >> "$PROJ/$BIG.jsonl"
python3 "$ENGINE" --resolve facade | head -1 | grep -q "^$BIG	"

# ...but an ID that is not indexed is a miss (exit 1), never the session that
# merely quotes it (a handoff naming its predecessor, a VPS-only session)
QUOTER="abcdef01-1111-2222-3333-444444444444"
{ printf '{"type":"user","cwd":"/data/quoter","timestamp":"2026-07-22T10:00:00Z","message":{"content":"handoff: continue the work of session 9f8e7d6c-aaaa-bbbb-cccc-dddddddddddd"}}\n'
  for i in $(seq 40); do
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"padding line %d to clear the small-file filter ................................"}]}}\n' "$i"
  done
} > "$PROJ/$QUOTER.jsonl"
python3 "$ENGINE" --find "9f8e7d6c" | grep -q "claude --resume $QUOTER"   # it IS indexed
for Q in 9f8e7d6c 9f8e7d6c-aaaa-bbbb-cccc-dddddddddddd; do
  if python3 "$ENGINE" --resolve "$Q" >/dev/null 2>&1; then
    echo "FAIL: --resolve $Q returned a session that only quotes that id"; exit 1
  fi
done
python3 "$ENGINE" --resolve abcdef01 | grep -q "^$QUOTER	"

# one malformed transcript never breaks a call, now or on the next call, and
# is not re-read until it changes
BAD="0badbad0-1111-2222-3333-444444444444"
{ printf '{"type":"user","cwd":"/data/bad","timestamp":"2026-07-22T10:00:00Z","message":{"content":[{"type":"text","text":null}]}}\n'
  printf '{"type":"custom-title","customTitle":{"not":"a string"}}\n'
  printf '{"type":"ai-title","aiTitle":42}\n'
  printf '"a bare string record"\n'
  printf '{"type":"user","cwd":"/data/bad","message":{"content":"walrus tuning notes"}}\n'
  for i in $(seq 40); do
    printf '{"type":"assistant","message":{"content":[{"type":"text","text":"padding line %d to clear the small-file filter ................................"}]}}\n' "$i"
  done
} > "$PROJ/$BAD.jsonl"
python3 "$ENGINE" --find "walrus" | grep -q "claude --resume $BAD"
python3 "$ENGINE" --find "frobnicator template" | grep -q "claude --resume $SID"
python3 "$ENGINE" >/dev/null

# a missing account root (unmounted, another HOME) does not empty the index
mv "$TMP/home/.claude/projects" "$TMP/home/.claude/projects.away"
python3 "$ENGINE" --resolve aaaaaaaa >/dev/null 2>&1 || true
mv "$TMP/home/.claude/projects.away" "$TMP/home/.claude/projects"
python3 -c "
import sqlite3; db=sqlite3.connect('$TMP/home/.cache/session-atlas/index.db')
n=db.execute('SELECT COUNT(*) FROM sessions').fetchone()[0]
assert n >= 5, 'index emptied while the root was missing: %d rows' % n"

# the exact-id lookup is an index lookup, not a table scan: EXPLAIN the SQL
# the engine itself runs, captured from its connection
python3 - "$ENGINE" <<'PY2'
import importlib.machinery, importlib.util, sys
ld = importlib.machinery.SourceFileLoader("sa", sys.argv[1])
sa = importlib.util.module_from_spec(importlib.util.spec_from_loader("sa", ld)); ld.exec_module(sa)
db = sa._connect(); seen = []
db.set_trace_callback(seen.append); sa.by_sid(db, "abcdef01"); db.set_trace_callback(None)
q = [x for x in seen if "FROM sessions" in x][0]
plan = " ".join(str(r[-1]) for r in db.execute("EXPLAIN QUERY PLAN " + q))
assert "sessions_sid" in plan, (q, plan)
PY2

# summaries.json keeps carrying names for sibling tools that read it directly
python3 "$ENGINE" >/dev/null
python3 -c "
import json; c=json.load(open('$TMP/home/.cache/session-atlas/summaries.json'))
assert c['$RENAMED']['name']=='Operator rename wins', c['$RENAMED']
assert c['$SID']['gist']=='Smoke-test gist line.', c['$SID']"

# a render never marks an old gist current: a session that moved after its
# gist was written is queued again
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"frobnicator follow-up work"}]}}\n' >> "$PROJ/$SID.jsonl"
python3 "$ENGINE" >/dev/null
python3 "$ENGINE" --gist-queue --limit 50 >/dev/null
python3 -c "
import json; q=json.load(open('$TMP/home/.cache/session-atlas/gist-queue.json'))
assert '$SID' in [i['sid'] for i in q['items']], 'stale gist not re-queued'
c=json.load(open('$TMP/home/.cache/session-atlas/summaries.json'))
assert c['$SID']['gist']=='Smoke-test gist line.', c['$SID']"

# a stale index schema is rebuilt, not trusted
python3 -c "
import sqlite3; db=sqlite3.connect('$TMP/home/.cache/session-atlas/index.db')
db.execute('PRAGMA user_version=0'); db.commit()"
python3 "$ENGINE" --resolve cccccccc | grep -q "Widget subsystem rewrite"
python3 "$ENGINE" --index-status | grep -q "^t1	"

# whole-word matches outrank prefix matches ("build 3" is not "build 31")
for T in "3:ledger build 3" "31:ledger build 31"; do
  N="${T%%:*}"; TITLE="${T#*:}"; S="1234567${N:0:1}-aaaa-4bbb-8ccc-0000000000${N}"
  S="$(printf '%s' "$S" | cut -c1-36)"
  { printf '{"type":"user","cwd":"/data/ledger","timestamp":"2026-07-22T10:00:00Z","message":{"content":"ledger work"}}\n'
    printf '{"type":"custom-title","customTitle":"%s"}\n' "$TITLE"
    for i in $(seq 40); do
      printf '{"type":"assistant","message":{"content":[{"type":"text","text":"padding line %d to clear the small-file filter ................................"}]}}\n' "$i"
    done
  } > "$PROJ/$S.jsonl"
done
touch -d "1 hour ago" "$PROJ"/12345673-*.jsonl   # the exact match is the OLDER one
python3 "$ENGINE" --resolve "ledger build 3" | head -1 | grep -q "ledger build 3$"

# --- the full-text layer -----------------------------------------------------
# A helper that loads the engine and reports what the index stores and what the
# incremental reader was asked to do, so the tests assert on mechanism, not luck.
FT="$TMP/ft.py"
cat > "$FT" <<'PYEOF'
import importlib.machinery, importlib.util, json, os, sys
ld = importlib.machinery.SourceFileLoader("sa", os.environ["ENGINE"])
sa = importlib.util.module_from_spec(importlib.util.spec_from_loader("sa", ld)); ld.exec_module(sa)
db = sa._connect()
calls = []
orig = sa.ft_extract
def spy(path, off, room):
    calls.append(off)
    return orig(path, off, room)
sa.ft_extract = spy
cmd = sys.argv[1]
if cmd == "meta":  # (offset consumed, text length, capped) for one session
    r = db.execute("SELECT m.off, m.tlen, m.capped FROM ftmeta m JOIN sessions s ON s.id = m.id "
                   "WHERE s.sid = ?", (sys.argv[2],)).fetchone()
    print(json.dumps(tuple(r) if r else None))
elif cmd == "cap":
    print(sa.FT_CAP)
elif cmd == "update":  # run one index update, report the offsets it read from
    sa.update_index(db); db.commit()
    print(json.dumps(calls))
PYEOF
ftmeta() { ENGINE="$ENGINE" python3 "$FT" meta "$1"; }
ftupdate() { ENGINE="$ENGINE" python3 "$FT" update; }
jfield() { python3 -c "import json,sys; print(json.loads(sys.argv[1])[int(sys.argv[2])])" "$1" "$2"; }
lines_pad() { for i in $(seq "${1:-40}"); do printf '{"type":"assistant","message":{"content":[{"type":"text","text":"padding line %d to clear the small-file filter ................................"}]}}\n' "$i"; done; }

# 1. a term that lives only in a tool_result in the MIDDLE of a large transcript
#    is found; the head and tail windows cannot see it
MID="11111111-2222-4333-8444-555555555555"
python3 - "$PROJ/$MID.jsonl" <<'PY'
import json, sys
def w(fh, o): fh.write(json.dumps(o) + "\n")
with open(sys.argv[1], "w") as fh:
    w(fh, {"type": "user", "cwd": "/data/mid-repo", "timestamp": "2026-07-22T10:00:00Z",
           "message": {"content": "inspect the quarterly widget report"}})
    for i in range(3000):  # ~1 MB of records that carry no searchable text
        w(fh, {"type": "system", "note": "bookkeeping %d " % i + "x" * 300})
    w(fh, {"type": "assistant", "message": {"content": [
        {"type": "thinking", "thinking": "private musing about lemniscate"},
        {"type": "tool_use", "id": "t1", "name": "Bash",
         "input": {"command": "grep -r marmalade-sprocket /srv/reports"}}]}})
    w(fh, {"type": "user", "message": {"content": [
        {"type": "tool_result", "tool_use_id": "t1",
         "content": "report.txt: vermicelli-quasar reconciled at 41 percent"}]}})
    w(fh, {"type": "user", "isMeta": True, "message": {"content": "injected skill text about zeppelinesque"}})
    for i in range(3000):
        w(fh, {"type": "system", "note": "bookkeeping %d " % i + "y" * 300})
    w(fh, {"type": "assistant", "message": {"content": [{"type": "text", "text": "the report is done"}]}})
PY
test "$(stat -c %s "$PROJ/$MID.jsonl")" -gt 1500000
python3 "$ENGINE" --find "vermicelli-quasar" | grep -q "claude --resume $MID"
python3 "$ENGINE" --find "marmalade sprocket" | grep -q "claude --resume $MID"   # a tool_use input
if python3 "$ENGINE" --find "lemniscate" | grep -q "$MID"; then
  echo "FAIL: a thinking block was indexed"; exit 1; fi
if python3 "$ENGINE" --find "zeppelinesque" | grep -q "$MID"; then
  echo "FAIL: an injected (isMeta) turn was indexed"; exit 1; fi
# several words that appear somewhere in the transcript, none of them in its title
python3 "$ENGINE" --resolve "widget vermicelli reconciled" | head -1 | grep -q "^$MID	"
python3 "$ENGINE" --index-status | grep -q "^fulltext	"

# 2. appending makes new terms findable by reading ONLY the new bytes
M0="$(ftmeta "$MID")"; OFF0="$(jfield "$M0" 0)"
test "$OFF0" = "$(stat -c %s "$PROJ/$MID.jsonl")"
if python3 "$ENGINE" --find "nautilus-gasket" | grep -q "$MID"; then echo "FAIL: found before written"; exit 1; fi
printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t2","content":"kiln log: nautilus-gasket replaced"}]}}\n' >> "$PROJ/$MID.jsonl"
# a record still being written (no newline yet) is left for the next call
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"half-written obsidian-turnip' >> "$PROJ/$MID.jsonl"
test "$(ftupdate)" = "[$OFF0]"      # the reader started at the stored offset, not at 0
python3 "$ENGINE" --find "nautilus-gasket" | grep -q "claude --resume $MID"
python3 "$ENGINE" --find "vermicelli-quasar" | grep -q "claude --resume $MID"   # earlier text kept
M1="$(ftmeta "$MID")"
test "$(jfield "$M1" 0)" -gt "$OFF0"
test "$(jfield "$M1" 1)" -gt "$(jfield "$M0" 1)"
test "$(jfield "$M1" 0)" -lt "$(stat -c %s "$PROJ/$MID.jsonl")"   # the unfinished line is not consumed
if python3 "$ENGINE" --find "obsidian-turnip" | grep -q "$MID"; then echo "FAIL: partial line read"; exit 1; fi
printf '"}]}}\n' >> "$PROJ/$MID.jsonl"    # the record completes
python3 "$ENGINE" --find "obsidian-turnip" | grep -q "claude --resume $MID"
test "$(ftupdate)" = "[]"                 # nothing new: nothing read

# 3. a truncated file, and a replaced file, are rebuilt from byte 0
{ head -c 3000 "$PROJ/$MID.jsonl" | head -n -1
  printf '{"type":"assistant","message":{"content":[{"type":"text","text":"after truncation: pumpernickel-lattice"}]}}\n'
  lines_pad; } > "$TMP/short.jsonl"
mv "$TMP/short.jsonl" "$PROJ/$MID.jsonl"
test "$(stat -c %s "$PROJ/$MID.jsonl")" -lt "$(jfield "$M1" 0)"
test "$(ftupdate)" = "[0]"
python3 "$ENGINE" --find "pumpernickel-lattice" | grep -q "claude --resume $MID"
if python3 "$ENGINE" --find "vermicelli-quasar" | grep -q "$MID"; then echo "FAIL: stale text after truncation"; exit 1; fi
# replaced by a LARGER file with a different beginning: size >= offset, first bytes differ
{ printf '{"type":"user","cwd":"/data/mid-repo","timestamp":"2026-07-23T10:00:00Z","message":{"content":"a different session entirely"}}\n'
  printf '{"type":"assistant","message":{"content":[{"type":"text","text":"replacement: gooseberry-anvil"}]}}\n'
  lines_pad 200; } > "$PROJ/$MID.jsonl"
test "$(stat -c %s "$PROJ/$MID.jsonl")" -gt "$(jfield "$(ftmeta "$MID")" 0)"
test "$(ftupdate)" = "[0]"
python3 "$ENGINE" --find "gooseberry-anvil" | grep -q "claude --resume $MID"
if python3 "$ENGINE" --find "pumpernickel-lattice" | grep -q "$MID"; then echo "FAIL: stale text after replacement"; exit 1; fi

# 4. the per-session cap is honored: text past it is not indexed, and a full
#    session is never read again
CAPD="22222222-3333-4444-8555-666666666666"
python3 - "$PROJ/$CAPD.jsonl" <<'PY'
import json, sys
def w(fh, o): fh.write(json.dumps(o) + "\n")
with open(sys.argv[1], "w") as fh:
    w(fh, {"type": "user", "cwd": "/data/cap-repo", "timestamp": "2026-07-22T10:00:00Z",
           "message": {"content": "capacity planning"}})
    for i in range(300):  # 300 x 3000 chars = 900k chars, far past the cap
        t = "record %d " % i + "filler " * 420
        if i == 10:  t += " earlybird-ferrule"
        if i == 120: t += " latecomer-ferrule"   # past the cap, outside the head and tail windows
        w(fh, {"type": "assistant", "message": {"content": [{"type": "text", "text": t}]}})
PY
python3 "$ENGINE" --find "earlybird-ferrule" | grep -q "claude --resume $CAPD"
if python3 "$ENGINE" --find "latecomer-ferrule" | grep -q "$CAPD"; then
  echo "FAIL: text past the cap was indexed"; exit 1; fi
MC="$(ftmeta "$CAPD")"; CAP="$(ENGINE="$ENGINE" python3 "$FT" cap)"
test "$(jfield "$MC" 2)" = 1
test "$(jfield "$MC" 1)" -le "$CAP"
test "$(jfield "$MC" 1)" -ge "$((CAP * 9 / 10))"
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"appended to a full session: tardigrade-gimbal"}]}}\n' >> "$PROJ/$CAPD.jsonl"
test "$(ftupdate)" = "[]"       # a full session is not read again
test "$(ftmeta "$CAPD")" = "$MC"

# 5. without contentless_delete (SQLite older than 3.43) a row is replaced through
#    FTS5's 'delete' command; append and replace must behave the same
H2="$TMP/home2"; P2="$H2/.claude/projects/-data-old"; mkdir -p "$P2"
cat > "$H2/config.json" <<EOF
{"accounts":[{"label":"t2","launcher":"claude","projects":"$H2/.claude/projects"}]}
EOF
OLDSID="33333333-4444-4555-8666-777777777777"
{ printf '{"type":"user","cwd":"/data/old","timestamp":"2026-07-22T10:00:00Z","message":{"content":"legacy sqlite path"}}\n'
  printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"a","content":"first: cormorant-sextant"}]}}\n'
  lines_pad; } > "$P2/$OLDSID.jsonl"
legacy() { HOME="$H2" SESSION_ATLAS_CONFIG="$H2/config.json" SESSION_ATLAS_NO_CONTENTLESS_DELETE=1 python3 "$ENGINE" "$@"; }
legacy --find "cormorant-sextant" | grep -q "claude --resume $OLDSID"
python3 -c "
import sqlite3; db=sqlite3.connect('$H2/.cache/session-atlas/index.db')
assert db.execute(\"SELECT v FROM meta WHERE k='ftx_cd'\").fetchone()[0]=='0'"
printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"b","content":"second: halyard-ballast"}]}}\n' >> "$P2/$OLDSID.jsonl"
legacy --find "halyard-ballast" | grep -q "claude --resume $OLDSID"
legacy --find "cormorant-sextant" | grep -q "claude --resume $OLDSID"
{ printf '{"type":"user","cwd":"/data/old","timestamp":"2026-07-24T10:00:00Z","message":{"content":"legacy replaced"}}\n'
  printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"c","content":"third: windlass-spindle"}]}}\n'
  lines_pad 80; } > "$P2/$OLDSID.jsonl"
legacy --find "windlass-spindle" | grep -q "claude --resume $OLDSID"
if legacy --find "cormorant-sextant" | grep -q "$OLDSID"; then echo "FAIL: stale legacy row"; exit 1; fi
rm -rf "$H2"

echo "smoke ok"

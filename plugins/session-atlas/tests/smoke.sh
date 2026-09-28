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

# a hex-looking topic that is no session's id falls through to topic search
python3 "$ENGINE" --resolve "deadbee" 2>/dev/null && { echo "FAIL: deadbee matched"; exit 1; }
printf '{"type":"custom-title","customTitle":"cafe01 menu rework"}\n' >> "$PROJ/$BIG.jsonl"
python3 "$ENGINE" --resolve cafe01 | head -1 | grep -q "^$BIG	"

# summaries.json keeps carrying names for sibling tools that read it directly
python3 "$ENGINE" >/dev/null
python3 -c "
import json; c=json.load(open('$TMP/home/.cache/session-atlas/summaries.json'))
assert c['$RENAMED']['name']=='Operator rename wins', c['$RENAMED']
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

echo "smoke ok"

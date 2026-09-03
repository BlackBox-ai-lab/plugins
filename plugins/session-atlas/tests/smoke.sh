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

echo "smoke ok"

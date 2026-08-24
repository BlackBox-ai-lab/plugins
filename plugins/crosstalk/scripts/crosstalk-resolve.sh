#!/usr/bin/env bash
# crosstalk-resolve.sh <target>
#
# Resolve a crosstalk target — a native session NAME, an 8-char short id, or a
# full session UUID — to exactly one session, live or past.
#
# Sources, in order:
#   1. The live session registry: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions/<pid>.json
#      Entries whose pid is no longer alive are skipped (the registry can hold
#      stale files after a crash). Matched on `name` exactly, then on `sessionId`
#      prefix.
#   2. Transcripts: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/*/<id>*.jsonl
#      — closed sessions, so /crosstalk:read and /crosstalk:quiet-ask still work
#      on them. The cwd comes from the first "cwd" field in the file.
#
# Output (stdout, exactly one line, tab-separated):
#   <sessionId>\t<cwd>\t<name>\t<status>
# where status is the registry status (busy|idle|waiting) or `closed`.
#
# Exit codes:
#   0  resolved — one line on stdout
#   1  no match, or ambiguous — candidates listed on stderr
#   2  the target is THIS session (the user pasted their own id or name);
#      nothing on stdout, the caller should ask for the real target
#
# Pure bash + jq. Read-only: it never writes anything, anywhere.
set -u

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "usage: crosstalk-resolve.sh <session-name|short-id|uuid>" >&2
  exit 1
fi

alive() { [ -d "/proc/$1" ] || kill -0 "$1" 2>/dev/null; }

# --- 1. live registry -------------------------------------------------------
name_hits=""   # newline-separated "sid\tcwd\tname\tstatus"
id_hits=""
shopt -s nullglob
for f in "$CFG"/sessions/*.json; do
  row=$(jq -r '[(.pid//empty),(.sessionId//empty),(.cwd//"-"),(.name//"-"),(.status//"-")]|@tsv' "$f" 2>/dev/null) || continue
  [ -z "$row" ] && continue
  IFS=$'\t' read -r pid sid cwd name status <<<"$row"
  [ -z "${pid:-}" ] && continue
  [ -z "${sid:-}" ] && continue
  alive "$pid" || continue
  if [ "$name" = "$TARGET" ]; then
    name_hits+="${sid}"$'\t'"${cwd}"$'\t'"${name}"$'\t'"${status}"$'\n'
  elif [ "${sid#"$TARGET"}" != "$sid" ]; then
    id_hits+="${sid}"$'\t'"${cwd}"$'\t'"${name}"$'\t'"${status}"$'\n'
  fi
done

pick=""
for bucket in "$name_hits" "$id_hits"; do
  [ -z "$bucket" ] && continue
  n=$(printf '%s' "$bucket" | grep -c '')
  if [ "$n" -eq 1 ]; then
    pick=$(printf '%s' "$bucket" | head -n1)
    break
  fi
  echo "crosstalk: '$TARGET' is ambiguous — $n live sessions match:" >&2
  printf '%s' "$bucket" | while IFS=$'\t' read -r s c nm st; do
    printf '  %s  %s  %s  [%s]\n' "${s:0:8}" "$nm" "$c" "$st" >&2
  done
  echo "Ask the user which one, or use the full session id." >&2
  exit 1
done

# --- 2. transcript fallback (closed sessions) -------------------------------
if [ -z "$pick" ]; then
  thits=""
  for t in "$CFG"/projects/*/"$TARGET"*.jsonl; do
    [ -f "$t" ] || continue
    base=$(basename "$t" .jsonl)
    cwd=$(grep -m1 -o '"cwd":"[^"]*"' "$t" 2>/dev/null | cut -d'"' -f4)
    thits+="${base}"$'\t'"${cwd:--}"$'\t'"-"$'\t'"closed"$'\n'
  done
  if [ -n "$thits" ]; then
    n=$(printf '%s' "$thits" | grep -c '')
    if [ "$n" -eq 1 ]; then
      pick=$(printf '%s' "$thits" | head -n1)
    else
      echo "crosstalk: '$TARGET' matches $n past sessions:" >&2
      printf '%s' "$thits" | while IFS=$'\t' read -r s c _nm _st; do
        printf '  %s  %s\n' "${s:0:8}" "$c" >&2
      done
      echo "Use more characters of the session id." >&2
      exit 1
    fi
  fi
fi

if [ -z "$pick" ]; then
  echo "crosstalk: no live or past session matches '$TARGET'." >&2
  echo "Run /crosstalk:list to see the sessions on this machine." >&2
  exit 1
fi

# --- self-reference ---------------------------------------------------------
rsid=$(printf '%s' "$pick" | cut -f1)
if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ "$rsid" = "$CLAUDE_CODE_SESSION_ID" ]; then
  exit 2
fi

printf '%s\n' "$pick"
exit 0

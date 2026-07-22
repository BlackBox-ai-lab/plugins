#!/usr/bin/env bash
# release-preflight.sh — every mechanical check that must pass before this
# marketplace goes public. Read-only: it inspects and reports, never edits.
#
#   bash scripts/release-preflight.sh            # checks only
#   bash scripts/release-preflight.sh --rehearse # + a real install into a throwaway HOME
#
# Exit 0 = every gate green. Exit 1 = at least one FAIL (see the summary).
# Companion runbook lives in the private ops repo (this repo ships user docs only).
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
PASS=0; FAIL=0; WARN=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; WARN=$((WARN+1)); }
sec()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

sec "1. Manifest validity (documented gate: claude plugin validate)"
if command -v claude >/dev/null; then
  if out=$(claude plugin validate . 2>&1); then
    ok "claude plugin validate . — passed"
    grep -qi warn <<<"$out" && warn "validator emitted warnings:
$(grep -i warn <<<"$out")"
  else
    bad "claude plugin validate . failed:
$out"
  fi
else
  warn "claude CLI not on PATH — skipped the documented validator"
fi

sec "2. Marketplace name is legal for a third party"
python3 - <<'PY'
import json, re, sys
RESERVED = {"claude-code-marketplace","claude-code-plugins","claude-plugins-official",
 "claude-plugins-community","claude-community","anthropic-marketplace","anthropic-plugins",
 "agent-skills","anthropic-agent-skills","knowledge-work-plugins","life-sciences",
 "claude-for-legal","claude-for-financial-services","financial-services-plugins",
 "first-party-plugins","healthcare"}
m = json.load(open(".claude-plugin/marketplace.json"))
n = m.get("name","")
bad = n in RESERVED or re.search(r"official|anthropic", n, re.I)
print(("  \033[31mFAIL\033[0m  " if bad else "  \033[32mPASS\033[0m  ") +
      ("name %r is reserved or impersonates an official source" % n if bad
       else "name %r is not reserved and does not impersonate Anthropic" % n))
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

sec "3. Names are kebab-case (claude.ai marketplace sync rejects other forms)"
python3 - <<'PY'
import json, re, sys
m = json.load(open(".claude-plugin/marketplace.json"))
KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
bad = [n for n in [m.get("name","")] + [p.get("name","") for p in m.get("plugins",[])]
       if not KEBAB.match(n)]
for b in bad: print("  \033[31mFAIL\033[0m  %r is not kebab-case" % b)
if not bad: print("  \033[32mPASS\033[0m  marketplace and all plugin names are kebab-case")
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

sec "4. Required manifest fields (marketplace + every plugin)"
python3 - <<'PY'
import json, os, sys
bad = []
m = json.load(open(".claude-plugin/marketplace.json"))
for f in ("name","owner","plugins"):
    if not m.get(f): bad.append("marketplace.json missing required %r" % f)
if not (m.get("owner") or {}).get("name"): bad.append("marketplace.json owner.name is required")
for e in m.get("plugins", []):
    for f in ("name","source"):
        if not e.get(f): bad.append("plugin entry %r missing required %r" % (e.get("name","?"), f))
    src = e.get("source")
    if isinstance(src, str) and src.startswith("./"):
        pj = os.path.join(src, ".claude-plugin", "plugin.json")
        if not os.path.exists(pj):
            bad.append("%s: no plugin.json at %s" % (e["name"], pj)); continue
        p = json.load(open(pj))
        if e.get("version") and p.get("version") and e["version"] != p["version"]:
            bad.append("%s: marketplace version %s != plugin.json %s (users will not get updates)"
                       % (e["name"], e["version"], p["version"]))
        if not p.get("version"):
            bad.append("%s: plugin.json has no version — pin it or updates are SHA-based" % e["name"])
for b in bad: print("  \033[31mFAIL\033[0m  " + b)
if not bad: print("  \033[32mPASS\033[0m  all required fields present; versions consistent")
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

sec "5. Nothing private leaks into a public repo"
# Generic patterns only. Your own machine/host/user identifiers do NOT belong in a
# public repo — not even as scanner patterns — so add them in an untracked file:
#   scripts/.leak-patterns.local   (one extended-regex alternation, no newline)
# Deliberately-public strings that would otherwise match (e.g. a brand contact
# address) go one-per-line in:
#   scripts/.leak-allow.local
# or the RELEASE_LEAK_PATTERNS environment variable.
# /home/<name> is flagged only for names that look real; synthetic fixture paths
# like /home/x or /home/user are how tests are supposed to be written.
LEAK='ANTHROPIC_API_KEY|sk-ant-|ghp_|gho_|github_pat_|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|xox[baprs]-|/home/(?!x/|user/|users/|test|example|me/|you/|alice|bob|someone)[a-z][a-z0-9._-]{2,}'
EXTRA=""
[ -f scripts/.leak-patterns.local ] && EXTRA=$(tr -d '\n' < scripts/.leak-patterns.local)
[ -n "${RELEASE_LEAK_PATTERNS:-}" ] && EXTRA="${EXTRA:+$EXTRA|}$RELEASE_LEAK_PATTERNS"
[ -n "$EXTRA" ] && LEAK="$LEAK|$EXTRA"
if hits=$(grep -rniP "$LEAK" --include='*.md' --include='*.json' --include='*.sh' --include='*.py' \
          plugins/ .claude-plugin/ README.md docs/ scripts/ 2>/dev/null \
          | grep -v 'example\.\|placeholder' \
          | { [ -f scripts/.leak-allow.local ] && grep -vFf scripts/.leak-allow.local || cat; } \
          | grep -v '^scripts/release-preflight\.sh:'); then   # this file defines the patterns
  bad "operator/machine details or credentials found:
$hits"
else
  ok "no usernames, hostnames, home paths, or credential patterns"
fi

sec "6. Licensing and per-plugin docs"
python3 -c "
import json;m=json.load(open('.claude-plugin/marketplace.json'))
print('  \033[32mPASS\033[0m  marketplace has a description' if m.get('description') else '  \033[33mWARN\033[0m  no marketplace description (validator warns; users see it)')" 
[ -f LICENSE ] && ok "LICENSE present at repo root" || bad "no LICENSE at repo root"
for d in plugins/*/; do
  p=$(basename "$d")
  [ -f "$d/README.md" ] || { bad "$p: no README.md"; continue; }
  grep -q "plugin marketplace add" "$d/README.md" \
    && ok "$p: README documents the install" || bad "$p: README has no install instructions"
done

sec "7. Tests"
shopt -s nullglob
for t in plugins/*/tests/*.sh; do
  p=$(basename "$(dirname "$(dirname "$t")")"); n=$(basename "$t")
  if bash "$t" >/dev/null 2>&1; then ok "$p: $n passed"; else bad "$p: $n FAILED"; fi
done
shopt -u nullglob

sec "8. Git state"
[ -z "$(git status --porcelain)" ] && ok "working tree clean" || bad "uncommitted changes present"
git fetch -q origin 2>/dev/null || true
if [ "$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)" = "0" ]; then
  ok "everything pushed to origin"
else
  bad "unpushed commits — users install from the remote, not your disk"
fi

sec "9. Repository visibility (the actual launch switch)"
if command -v gh >/dev/null && vis=$(gh repo view --json visibility -q .visibility 2>/dev/null); then
  if [ "$vis" = "PUBLIC" ]; then
    ok "repo is PUBLIC — the documented install commands work for anyone"
  else
    warn "repo is $vis — install fails for anyone without access. This is the last step, and it is yours to take."
  fi
else
  warn "could not determine visibility (gh not available)"
fi

if [ "${1:-}" = "--rehearse" ]; then
  sec "10. Fresh-install rehearsal (throwaway HOME, exactly what a newcomer runs)"
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
  mkdir -p "$T/home" "$T/blank"
  MK=$(python3 -c "import json;print(json.load(open('.claude-plugin/marketplace.json'))['name'])")
  if (cd "$T/blank" && HOME="$T/home" claude plugin marketplace add "$ROOT" >/dev/null 2>&1); then
    ok "marketplace add succeeded"
    for e in $(python3 -c "import json;[print(p['name']) for p in json.load(open('.claude-plugin/marketplace.json'))['plugins']]"); do
      if (cd "$T/blank" && HOME="$T/home" claude plugin install "$e@$MK" >/dev/null 2>&1); then
        n=$(cd "$T/blank" && HOME="$T/home" claude plugin details "$e@$MK" 2>/dev/null | grep -c 'Skills')
        [ "$n" -ge 1 ] && ok "$e installed and reports its components" || bad "$e installed but reports nothing"
      else
        bad "$e failed to install"
      fi
    done
  else
    bad "marketplace add failed against a clean HOME"
  fi
fi

printf '\n\033[1mSummary:\033[0m %d passed, %d failed, %d warnings\n' "$PASS" "$FAIL" "$WARN"
[ "$FAIL" -eq 0 ] && echo "Mechanical gates are green. Remaining steps are in the private release runbook." \
                  || echo "Fix the FAIL lines above before publishing."
exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)

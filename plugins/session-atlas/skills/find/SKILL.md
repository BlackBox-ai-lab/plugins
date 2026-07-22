---
name: find
description: Find a past Claude Code session by topic and hand back its resume command. Use when the user asks "where's my session about X", "get me back into that conversation", or wants to resume work they can't locate.
argument-hint: "<a few keywords>"
---

# /session-atlas:find

Deterministic, token-cheap, stdlib-only — **never Read page HTML or transcripts
into context**; interact only through the commands below.

1. Run:
   ```
   ${CLAUDE_PLUGIN_ROOT}/scripts/session-atlas --find "<a few keywords>"
   ```
   Sessions matching **all** terms rank first; the index covers titles, first
   prompts, gists, and (for recent sessions) words from the transcript tail.
   Each hit prints `date [repo] (account) [● running]  topic` plus a
   `cd <dir> && <launcher> --resume <sid>` line.
2. Relay the best 1–3 hits **verbatim** (keep the `● running` flag — resuming a
   live session forks it; the operator should pick one instance).
3. **Ambiguous?** If two or three candidates could be "the one", don't guess and
   don't grep transcripts — ask each candidate session itself with a throwaway
   read-only fork (works on closed sessions, leaves them untouched):
   ```
   cd <candidate-cwd> && <candidate-launcher> -p "One line only: did this session <the thing the user described>? Answer yes/no + what was built." \
     --resume <candidate-sid> --fork-session --permission-mode dontAsk \
     --disallowedTools "Bash,Edit,Write,NotebookEdit,Task,WebFetch,WebSearch"
   ```
   (Prompt must come right after `-p` — `--disallowedTools` is variadic and will
   swallow a trailing prompt.) Relay the confirmed session's resume command.

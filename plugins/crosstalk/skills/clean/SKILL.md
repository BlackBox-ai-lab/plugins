---
name: clean
description: Janitor for crosstalk's own state - sweep grants and fleet entries belonging to sessions that no longer exist, and offer to remove the legacy 1.x mail directory. Never touches repos, worktrees, or live sessions' state.
disable-model-invocation: true
---

# /crosstalk:clean — no residue, even in our own directory

Scope: `CT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk"` ONLY — never any repo, worktree, or
transcript. A session id counts as **gone** when
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/crosstalk-resolve.sh" "<id>"` finds neither a live registry
entry nor a transcript.

1. **Dead session dirs:** for each `<sid>/` dir (skip `exchanges/`): if the session is gone AND
   the newest file in the dir is older than 30 days → delete the dir.
2. **Dangling grants:** in surviving dirs, drop `consultants` lines whose peer is gone; delete a
   `chatty` file whose peer is gone; delete a `report-to` whose hub is gone; drop `roster` lines
   whose spoke is gone (and mention each removed spoke by alias, since a hub may want to
   re-adopt).
3. **Exchange logs:** leave them (cheap, useful history) unless older than 90 days → delete that
   pair dir.
4. **Legacy 1.x state:** if `$HOME/.claude/session-mail/` exists, it is crosstalk 1.x residue —
   mailboxes, `ENABLED`, `names.json`. Show its size and **ask the user** before removing it;
   never delete it silently.
5. Report a one-line summary: N session dirs swept, N grants pruned, N roster lines dropped,
   N exchange dirs expired. Nothing else touched.

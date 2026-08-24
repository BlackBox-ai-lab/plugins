# Maintainer notes for this repository

This repository is public and installable by anyone; the plugins in it are documented in
`README.md` and each plugin's own README. These notes are for maintainers.

## How changes land here

- **No CI and no branch protection.** The release gate is `scripts/release-preflight.sh`
  (run it from the pushed branch; it must report zero failures). Changes land by **direct
  push to `main`** after the gate passes — there is no auto-merge to wait for.
- **Do not open pull requests or issues here from a personal GitHub login.** GitHub keeps
  PR and issue records permanently, and a merge from a personal login also re-authors the
  squash commit. Everything maintainer-facing on this repo is attributed to the Blackbox AI
  Labs account. If a PR is genuinely wanted, switch `gh` to that account first
  (`gh auth switch`), and switch back afterwards. The preflight's "GitHub records" gate
  fails when any PR or issue carries another login.
- **Commit identity is set per repository.** Verify before every push:
  `git log --format='%an <%ae>' | sort -u` must show only the Blackbox AI Labs identity.
- **Public repo, user documentation only.** Design notes, decisions, plans and anything
  else that is not for a user of the plugins live elsewhere; do not add them here.

## Plugin conventions

- Bump the plugin's `version` in `plugins/<name>/.claude-plugin/plugin.json` **and** the
  matching entry in `.claude-plugin/marketplace.json` in the same change.
- Every plugin keeps a hermetic test (`plugins/<name>/tests/`) that never touches real
  user state; the preflight runs them.
- `crosstalk` builds on Claude Code's native cross-session messaging (2.1.224+) and keeps its
  state under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/`; it must never write inside a
  repository or worktree.

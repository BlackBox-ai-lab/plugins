# Blackbox AI Labs — Claude Code plugin marketplace

Free, installable [Claude Code](https://code.claude.com/docs) plugins from Blackbox AI
Labs. If you got here from a video: everything you saw is below, it installs in two
commands, and it costs nothing.

This repo *is* the marketplace — Claude Code adds marketplaces straight from a git repo,
so there is nothing else to sign up for.

| Plugin | What it gives you |
|---|---|
| **[crosstalk](plugins/crosstalk)** | Session-to-session messaging: full sessions on one machine that can message each other, silently consult each other's context, and self-organize into an orchestrator + builder fleet. Default OFF, every action operator-gated. |
| **[session-atlas](plugins/session-atlas)** | The standing map of every session on a machine: living HTML pages (search, "where we left off" gists, resume commands) plus an agent-safe find/resolve/import CLI. No credentials — gists are written by your own session's model. |

## Install

Two routes. Both end with the same thing installed; pick whichever you prefer.

**A — straight from GitHub** (nothing to clone):

```
/plugin marketplace add BlackBox-ai-lab/plugins
/plugin install crosstalk@blackbox-ai-labs
/plugin install session-atlas@blackbox-ai-labs
```

**B — clone first, install from the working copy** (read the code before you run it,
or track a fork):

```
git clone https://github.com/BlackBox-ai-lab/plugins.git blackbox-plugins
/plugin marketplace add ./blackbox-plugins
/plugin install session-atlas@blackbox-ai-labs
```

Working from a private fork, or added as a collaborator on a private repo? The SSH
source form is supported and uses your existing git credentials:

```
/plugin marketplace add git@github.com:BlackBox-ai-lab/plugins.git
```

Both work outside a session too, if you'd rather script it — the same commands
without the leading slash:

```
claude plugin marketplace add BlackBox-ai-lab/plugins
claude plugin install session-atlas@blackbox-ai-labs
```

**Then run `/reload-plugins`** to activate them in your current session — no restart
needed. (Restarting works too.) Verify with `claude plugin list`,
or just type `/` and look for the `crosstalk:` and `session-atlas:` verbs.

To pick up a new version later: `claude plugin marketplace update blackbox-ai-labs`
followed by `claude plugin update <plugin>@blackbox-ai-labs`, then restart. The
marketplace update alone is not enough — the second command is what re-fetches the
plugin itself.

### Prerequisites

- **A recent Claude Code.** Check with `claude --version`. If `/plugin` comes back as an
  unknown command, update first — see [Setup](https://code.claude.com/docs/en/setup).
- **crosstalk** — `jq` on PATH. One machine: it connects sessions on the same host (any project, any worktree).
- **session-atlas** — Python 3 (standard library only). No API key: the engine never calls a model.

Neither plugin needs an Anthropic API key, an account beyond the one already running
Claude Code, or any network service.

## Crosstalk

Sessions exchange operator-authorized mail through per-session mailboxes under `~/.claude/session-mail/`, delivered by hooks: a **working** session receives mail at the end of its current turn (no keypress); an **idle** one on its user's next prompt. A silent consult path answers questions from a peer session's full context via a throwaway read-only fork — the peer's live window never moves.

| Verb | What it does |
|---|---|
| `/crosstalk:on` · `off` | Machine-wide master switch. **Default OFF.** |
| `/crosstalk:request <target> <msg>` | Mail the live peer; it acts and responds at its next turn boundary |
| `/crosstalk:quiet-ask <target> <q>` | A read-only fork of the peer's context answers; the peer never sees it |
| `/crosstalk:observe <target>` · `unobserve` | Standing grant: this session may quiet-ask that peer on its own initiative (read-only, always surfaced) |
| `/crosstalk:chatty <target>` | Mutual pair: both sides may quiet-ask each other + send short delta updates |
| `/crosstalk:status` | Switch, pair, grants, mailbox counts at a glance |
| `/crosstalk:list` | Recent sessions on this machine (targets) |
| `/crosstalk:name <alias>` | Friendly alias for this session |
| `/crosstalk:read <target> [q]` | Mine a (possibly closed) session's transcript via subagent |
| `/crosstalk:stop` | Tear down pair + all grants (keeps mailboxes) |

### Orchestration (hub & spokes)

Run one session as the **hub** of a fleet of builder sessions: spokes push short delta reports to the hub (delivered at its turn ends); the hub holds read-only quiet-ask on every spoke; spokes never talk to each other — the hub is the only cross-spoke channel. A per-turn reminder keeps every role alive across context compaction.

| Verb | What it does |
|---|---|
| `/crosstalk:orchestrator [alias]` | Take on the hub role (playbook: reports, externalized team-state, efficiency ladder) |
| `/crosstalk:enlist <hub> "<task>"` | Run in a NEW builder: self-register under the hub — no ids to copy. `--succeeds <old>` = handoff succession |
| `/crosstalk:adopt [target]` | Hub-side: pick a running session from a recent-sessions menu and adopt it |
| `/crosstalk:team` | Fleet view: roster, last report, staleness/conflict flags |
| `/crosstalk:release <alias>` | Remove a spoke + its grants |
| `/crosstalk:clean` | Janitor: sweep dead mailboxes, expired forward pointers, dangling aliases |

Succession after a handoff is automatic: an enlisted session invoking a handoff gets a hook-injected reminder to put `enlist --succeeds` in the handoff doc; the successor reuses the alias, in-flight mail follows a forward pointer, and no old-session history is carried along.

Delivery honesty: a **working** session receives mail at its next turn end with no keypress; a session **idle at its prompt** receives it on its user's next keypress — no native mechanism can wake an idle session (doc-verified). A reserved design for tmux-based wake + fleet spawning lives in [docs/TMUX-WAKE.md](docs/TMUX-WAKE.md); it is deliberately not shipped.

Targets are session ids (full or first-8), or aliases from `/crosstalk:name`.

## Safety model

Built after a real incident: within a day of the original skill shipping, unrelated sessions emergently adopted it and mailed each other unprompted. The lockdown that followed is layered and load-bearing — don't weaken it:

- **Default OFF** — one machine-wide switch (`~/.claude/session-mail/ENABLED`); absent means every path refuses. Only the operator flips it.
- **No auto-invocation** — action verbs are `disable-model-invocation: true`; only a typed command runs them.
- **Never self-initiate** — a session acts only on its operator's explicit command, mail actually delivered to it, or a standing grant the operator created. Standing grants authorize **read-only** consults only.
- **Rate-limited active delivery** — at most 15 autonomous turn-end deliveries per 300 s per session; past the cap, mail waits for a human keypress.
- **Injection hygiene** — delivered mail is framed as information from another session, not operator instructions; conflicting or destructive directives get confirmed with the human first.

Trust boundary, stated honestly: transcripts and mailboxes are plain files under `$HOME` — grants govern what an agent may do *on its own initiative*, not what is technically reachable by processes on your machine.

## Status line (optional)

To show your session id and pair indicator in the Claude Code status line, add to your statusline command: short id = first 8 of the `.session_id` field from statusline stdin; show `⇄ <peer8>` when both `~/.claude/session-mail/ENABLED` and `<sid>/link` exist.

## License

MIT

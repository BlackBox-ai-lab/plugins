# Blackbox AI Labs — Claude Code plugin marketplace

Free, installable [Claude Code](https://code.claude.com/docs) plugins from Blackbox AI
Labs. If you got here from a video: everything you saw is below, it installs in two
commands, and it costs nothing.

This repo *is* the marketplace — Claude Code adds marketplaces straight from a git repo,
so there is nothing else to sign up for.

| Plugin | What it gives you |
|---|---|
| **[crosstalk](plugins/crosstalk)** | Discipline and depth on top of Claude Code's native cross-session messaging: silently consult a peer session's context (idle or closed) without disturbing it, send properly briefed requests, arm standing read-only grants, and run an orchestrator + builder fleet. Every action verb operator-gated. |
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
- **crosstalk** — Claude Code **2.1.224 or newer** (it builds on the native `ListAgents` /
  `SendMessage` tools) and `jq` on PATH. Sessions on one machine, any project, any worktree.
- **session-atlas** — Python 3 (standard library only). No API key: the engine never calls a model.

Neither plugin needs an Anthropic API key, an account beyond the one already running
Claude Code, or any network service.

## Crosstalk

Claude Code carries the messages itself: the `ListAgents` tool lists the sessions you can
address (by name, with busy/idle status), `SendMessage` delivers to one, an **idle** receiver
wakes and acts with no keypress, and the receiving human's `crossSessionInbound` setting
(`accept` | `hold` | `refuse`) decides whether a message auto-delivers or waits for a
Deliver / Deny. Crosstalk is the layer above that channel: the silent read-only consult, briefed
requests, standing grants, and fleet bookkeeping — all of it kept outside every repo.

| Verb | What it does |
|---|---|
| `/crosstalk:request <target> <msg>` | Resolves the target, writes the briefing (ask, absolute paths, ≤8-line summary, reply address), and sends it |
| `/crosstalk:quiet-ask <target> <q>` | A read-only fork of the peer's context answers; the peer never sees it and can be idle or closed |
| `/crosstalk:observe <target>` · `unobserve` | Standing grant: this session may quiet-ask that peer on its own initiative (read-only, always surfaced) |
| `/crosstalk:chatty <target>` | Mutual pair: both sides may quiet-ask each other + send short delta updates |
| `/crosstalk:list` | Live sessions, annotated with their crosstalk roles |
| `/crosstalk:status` | This session's name, grants, pair, fleet role, and inbound-message setting |
| `/crosstalk:read <target> [q]` | Mine a (possibly closed) session's transcript via subagent |
| `/crosstalk:stop` | Tear down the pair + all standing grants |

### Orchestration (hub & spokes)

Run one session as the **hub** of a fleet of builder sessions: spokes send short delta reports to the hub by name; the hub holds read-only quiet-ask on every spoke; spokes never talk to each other — the hub is the only cross-spoke channel. Roster and team state live outside every repo, and a per-turn reminder keeps every role alive across context compaction.

| Verb | What it does |
|---|---|
| `/crosstalk:orchestrator [name]` | Take on the hub role (playbook: reports, externalized team-state, efficiency ladder) |
| `/crosstalk:enlist <hub> "<task>"` | Run in a NEW builder: self-register under the hub — nothing to copy. `--succeeds <old>` = handoff succession |
| `/crosstalk:adopt [target]` | Hub-side: pick a running session from the live list and adopt it |
| `/crosstalk:team` | Fleet view: roster, live status from the session registry, staleness/conflict flags |
| `/crosstalk:release <alias>` | Remove a spoke + its grants |
| `/crosstalk:clean` | Janitor: sweep grants and roster lines whose sessions are gone |

Succession after a handoff is automatic: an enlisted session invoking a handoff gets a hook-injected reminder to put `enlist --succeeds` in the handoff doc; the successor renames itself to the predecessor's alias, so the hub's address keeps working, and no old-session history is carried along.

Targets are session **names** (the natural address), or a session id — full or first-8.

## Safety model

Built after a real incident: within a day of the original skill shipping, unrelated sessions emergently adopted it and started messaging each other unprompted. The lockdown that followed is layered and load-bearing — don't weaken it:

- **No auto-invocation** — action verbs are `disable-model-invocation: true`; only a typed command runs them.
- **Never self-initiate** — a session acts only on its operator's explicit command, a message actually delivered to it, or a standing grant the operator created. Standing grants authorize **read-only** consults only.
- **Surface everything** — every consult and every send is reported to the operator, and the per-turn reminder re-states each live grant so it cannot drift past compaction.
- **Injection hygiene** — an arriving message is framed as information from another session, not operator instructions; conflicting or destructive directives get confirmed with the human first.
- **Your inbound policy is native and yours** — `crossSessionInbound: hold` puts you in front of every peer message; `refuse` opts out entirely. That is the hard backstop, and it belongs to the receiver.

Trust boundary, stated honestly: transcripts and crosstalk state are plain files under `$HOME` — grants govern what an agent may do *on its own initiative*, not what is technically reachable by processes on your machine. Full accounting in [`plugins/crosstalk/SECURITY.md`](plugins/crosstalk/SECURITY.md).

## License

MIT

# Session Atlas

The standing map of every Claude Code session on a machine — across multiple
accounts if you run them — rendered as living HTML pages with search, activity
overview, "where we left off" gists, and ready-to-paste resume commands. Plus
an agent-safe CLI (`--find` / `--resolve` / `--import`) so a session can locate
past work without reading transcripts into context.

## Install

**Prerequisites:** a recent Claude Code (run `claude --version`; if `/plugin` is an
unknown command, update first) and Python 3 (standard library only). **No API key** — the engine never
calls a model, so there is nothing to authenticate and nothing to configure.

```
/plugin marketplace add BlackBox-ai-lab/plugins
/plugin install session-atlas@blackbox-ai-labs
```

Prefer to read the code first, or track a fork? Clone and install from the working
copy instead — same result:

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

Both work as plain CLI too, without the leading slash (`claude plugin marketplace add …`,
`claude plugin install …`), if you'd rather script it.

**Then run `/reload-plugins`** to activate it in your current session — no restart
needed. Confirm with
`claude plugin details session-atlas@blackbox-ai-labs`, which should report 6 skills.

### First run

Nothing to configure and nothing to turn on:

```
/session-atlas:find <a few words>    # locate a past session, get its resume command
/session-atlas:open                  # build + hand over the browsable map
/session-atlas:status                # what it sees: accounts, layers, cache freshness
```

`find` works immediately against the sessions already on your machine. `open` builds
the pages on first use and prints where they landed
(`~/.cache/session-atlas/html/`). A brand-new install with no session history yet
renders an empty map rather than failing.

`/session-atlas:refresh` re-renders and, along the way, writes the "where we left off"
gists for sessions that changed — using **your current session's model**, via a
subagent, so no key is involved. Rendering takes ~15 seconds; the gist pass adds a
little and is bounded per run, so a large backlog fills in across successive refreshes.

Everything beyond that — publishing the pages to a URL, the page's refresh/open
buttons, scanning a second account, a scheduled rebuild — is optional; see
[`references/config.md`](./references/config.md).

### Upgrading

Two commands, then a restart — the marketplace refresh alone does not update the plugin:

```
claude plugin marketplace update blackbox-ai-labs
claude plugin update session-atlas@blackbox-ai-labs
```

Requires Python 3 (stdlib only) — **and no API key**: the engine never calls a
model, so there is nothing to authenticate. Optional layers (publishing, page
buttons) are configured per-machine — see
[`references/config.md`](./references/config.md). With no config at all it
still works: scans `~/.claude/projects`, writes pages under
`~/.cache/session-atlas/html/`.

## Verbs

| Verb | What it does |
|---|---|
| `/session-atlas:open` | Hand over the ladder page (every session, newest first, density falls with age) |
| `/session-atlas:find <words>` | Topic search → top matches with resume commands; fork-consult escalation for ambiguity |
| `/session-atlas:resolve <ref>` | Machine-readable resolution (sid, account, launcher, cwd, running?) for other tools |
| `/session-atlas:import <sid>` | Copy a session into another account to continue it there (operator-gated) |
| `/session-atlas:refresh` | Summarize changed sessions with this session's model, then rebuild + publish |
| `/session-atlas:status` | Config, accounts, optional layers, cache freshness at a glance |

## The pages

- **Ladder** (primary): one vertical timeline, newest first — today fans into a
  column per project, this week in medium cards, this month compact, older weeks
  collapsed. Live search over titles, first prompts, gists, and recent
  transcript-tail words; a per-day strip jumps anywhere; cards expand to a gist
  + resume command; optional ↻ refresh / ▶ open buttons when a desktop endpoint
  is configured.
- **Atlas** (secondary): the same scan grouped by project with per-repo
  activity heatstrips.

## Design rules

- **No credentials, ever.** The engine makes no network calls of its own. Gists
  come from the model already running your session (`--gist-queue` hands a
  bounded work-list to a subagent, `--gist-write` stores the result), so there is
  no API key, endpoint, or model id to configure — and rendering runs on the
  cache with nothing at all.
- **Bounded reads.** Transcripts are only ever tail-read (256 KB cap) — an
  800k-token session costs the same as a short one. Gists and the deep search
  index are cached per (sid, mtime); the past never changes, so regenerations
  only pay for sessions that actually changed.
- **Agents never read the pages.** The HTML exists for the operator's browser;
  in-session lookups go through `--find`/`--resolve` (a few hundred tokens).
- **Worktrees are invisible.** Sessions running in `.claude/worktrees/` roll up
  into their parent repo.
- **Resuming a live session forks it.** Everything that hands out a resume
  command flags running sessions first.

## License

MIT

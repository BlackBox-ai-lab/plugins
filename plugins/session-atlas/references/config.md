# session-atlas configuration

Everything machine-specific is config. **No config file is required** — a stock
single-account Claude Code install works out of the box and every optional layer
degrades cleanly.

Config file: `~/.config/session-atlas/config.json`, overridable with
`$SESSION_ATLAS_CONFIG`. All keys optional.

**There are no credentials here.** The engine never calls a model: the "where we
left off" gists are written by a Claude session's own model through
`--gist-queue` / `--gist-write` (see the `refresh` skill). Nothing in this file
is or references an API key, endpoint, or model id.

```jsonc
{
  // Accounts to scan. Default: one account, ~/.claude, launcher "claude".
  // "launcher" is whatever command starts Claude Code for that account
  // (a wrapper/alias if you run multiple accounts).
  "accounts": [
    {"label": "a1", "launcher": "claude",
     "projects": "~/.claude/projects", "sessions": "~/.claude/sessions"}
  ],

  // Where the published pages live (used for cross-links between the two
  // pages). Default: file:// paths under ~/.cache/session-atlas/html/.
  "atlas_url":  "https://example.internal/scratch/session-atlas.html",
  "ladder_url": "https://example.internal/scratch/session-ladder.html",
  "atlas_slug": "session-atlas",
  "ladder_slug": "session-ladder",

  // Optional: how to publish a rendered page. Shell string; {file} and {slug}
  // are substituted. Absent -> pages stay local files.
  "publish_cmd": "my-publish-tool {file} {slug}",

  // Optional: retired-slug redirect stub (only if you migrated from an older
  // page and want its URL to keep working).
  "timeline_redirect_slug": "session-timeline",

  // Optional: the endpoint the ladder's buttons call (see "refresh endpoint"
  // below). Absent -> the ↻ refresh and ▶ open buttons are not rendered.
  "refresh_url": "https://my-desktop.example.internal:8747/",

  // Optional: how the /launch endpoint opens a terminal. argv list; {cwd} and
  // {cmd} are substituted. Default: gnome-terminal.
  "terminal_cmd": ["gnome-terminal", "--working-directory", "{cwd}", "--",
                   "bash", "-ic", "{cmd}; exec bash -i"]
}
```

## Degradation table

| Missing config | Behavior |
|---|---|
| whole file | single account `~/.claude`, local pages, no buttons (gists still work — they need no config) |
| `publish_cmd` | pages written under `~/.cache/session-atlas/html/` only |
| `refresh_url` | ↻ refresh and ▶ open buttons not rendered |
| second account | single-account scan; `--import` refuses (nowhere to import to) |

## Running from automation (timers, cron) — which copy to invoke

Inside a Claude session the verb skills call the engine via
`${CLAUDE_PLUGIN_ROOT}/scripts/session-atlas`, which resolves to the installed
plugin. External automation has no such variable — it is only set inside a
session — so a timer has to find the script another way.

You *can* ask for the path: `claude plugin list --json` reports an `installPath`
per installed plugin, e.g.

```sh
claude plugin list --json \
  | python3 -c "import json,sys;print(next(e['installPath'] for e in json.load(sys.stdin) if e['id']=='session-atlas@blackbox-ai-labs'))"
```

Two caveats before you build on that. The path is **version-scoped**
(`…/session-atlas/1.1.1`) and the Claude Code docs say `${CLAUDE_PLUGIN_ROOT}`
"changes when the plugin updates… treat it as ephemeral" — so resolve it fresh on
every run, never cache it. And the `installPath` field is not published as a
stable schema, so treat it as a convenience rather than a contract.

If you would rather not depend on either, give the job its own copy of the script:

1. **Simplest — copy `scripts/session-atlas` to somewhere on `PATH`** and refresh
   that copy when you upgrade the plugin.
2. **Self-updating — let the job own a clone of this repo**, e.g. a bare mirror
   under `~/.cache/session-atlas/source.git` that it fetches each run and
   extracts the engine from. Upstream stays the source of truth, nothing depends
   on where (or whether) you keep a working checkout, and the last extraction
   still runs when the network is down.

Either way, note what the scheduled job can and cannot do: it renders and
publishes from the **cache**, which needs nothing. It cannot write new gists —
those come from a session's own model (the `refresh` skill). So a timer keeps the
page reachable and current-looking; gists for brand-new sessions land the next
time you run `/session-atlas:refresh` in a session.

Do **not** point a timer at the plugin cache, and do not point it at a personal
working checkout — the first moves on every upgrade, the second breaks the moment
the directory is renamed or removed.

## Scheduling (systemd user units)

```ini
# ~/.config/systemd/user/session-atlas.service
[Unit]
Description=session-atlas — regenerate + publish the living session map
[Service]
Type=oneshot
ExecStart=/bin/bash -lc '<path-to>/session-atlas --publish'
TimeoutStartSec=600

# ~/.config/systemd/user/session-atlas.timer
[Unit]
Description=Daily session-atlas refresh
[Timer]
OnCalendar=07:30
Persistent=true
[Install]
WantedBy=timers.target
```

`systemctl --user daemon-reload && systemctl --user enable --now session-atlas.timer`

## Refresh endpoint (optional, powers the page buttons)

A socket-activated per-connection handler; `session-atlas --refresh-http`
speaks minimal HTTP on stdin/stdout. `GET /` rebuilds + republishes
(flock-guarded); `GET /launch?sid=<uuid>` opens that session in a terminal —
only the sid crosses the wire; launcher and cwd are resolved server-side.

```ini
# session-atlas-refresh.socket
[Socket]
ListenStream=127.0.0.1:8747
Accept=yes
[Install]
WantedBy=sockets.target

# session-atlas-refresh@.service
[Service]
ExecStart=<path-to>/session-atlas --refresh-http
StandardInput=socket
StandardOutput=socket
StandardError=journal
TimeoutStartSec=600
KillMode=process
```

**Security:** the endpoint is unauthenticated and `/launch` opens terminals on
your machine. Bind it to localhost and expose it only over a private overlay
network you trust (e.g. `tailscale serve`), or not at all — the pages work fine
without it.

## Cache

`~/.cache/session-atlas/summaries.json` — per-session gists, late-rename names,
and the deep search index, keyed by (sid, mtime); entries idle >120 days are
pruned on save. Delete the file to rebuild from scratch (gists will be
re-generated over successive refreshes). `gist-queue.json` is the transient
work-list for the current gist pass. Pages render to
`~/.cache/session-atlas/html/`.

# Crosstalk

Session-to-session messaging for Claude Code: full sessions on one machine that can message
each other, silently consult each other's context, and self-organize into an orchestrator +
builder fleet. **Default OFF; every action operator-gated.**

## Install

**Prerequisites:** a recent Claude Code (run `claude --version`; if `/plugin` is an
unknown command, update first) and `jq` on PATH (`brew install jq` / `apt install jq`). Scope: sessions
on one machine — any project, any worktree. No API key, no network service, no account
beyond the one already running Claude Code.

```
/plugin marketplace add BlackBox-ai-lab/plugins
/plugin install crosstalk@blackbox-ai-labs
```

Prefer to read the code first, or track a fork? Clone and install from the working
copy instead — same result:

```
git clone https://github.com/BlackBox-ai-lab/plugins.git blackbox-plugins
/plugin marketplace add ./blackbox-plugins
/plugin install crosstalk@blackbox-ai-labs
```

Working from a private fork, or added as a collaborator on a private repo? The SSH
source form is supported and uses your existing git credentials:

```
/plugin marketplace add git@github.com:BlackBox-ai-lab/plugins.git
```

Both work as plain CLI too, without the leading slash (`claude plugin marketplace add …`,
`claude plugin install …`), if you'd rather script it.

**Then run `/reload-plugins`** — that activates it in your current session, so you can
keep going without restarting. The 19 verbs load as `/crosstalk:*`; the two hooks that
deliver mail (`UserPromptSubmit`, `Stop`) are registered automatically by the install —
there is nothing to wire by hand and nothing to add to your settings. Confirm with
`claude plugin details crosstalk@blackbox-ai-labs`, which should report 19 skills and
2 hooks.

### First run

Crosstalk is **OFF until you turn it on** — that is the top of the safety model, not a
setup step to skip past. Nothing delivers, and every verb refuses, until the master
switch exists:

```
/crosstalk:on          # machine-wide switch (~/.claude/session-mail/ENABLED)
/crosstalk:status      # switch, this session's id, pair, grants, mailbox counts
/crosstalk:list        # recent sessions on this machine — your available targets
```

Then, from one session, address another by its short id (first 8 characters) or an
alias you set with `/crosstalk:name`:

```
/crosstalk:request <target> what are you working on right now?
```

Watch the target session: it answers at the end of its current turn, with no keypress
from you. That one exchange is the whole mechanism — everything else stacks on it.

To take it back down: `/crosstalk:stop` (this session's pair and grants) or
`/crosstalk:off` (the machine-wide switch).

### Upgrading

Two commands, then a restart — the marketplace refresh alone does not update the plugin:

```
claude plugin marketplace update blackbox-ai-labs
claude plugin update crosstalk@blackbox-ai-labs
```

## What it does

| Verb | What it does |
|---|---|
| `/crosstalk:on` · `off` | Machine-wide master switch. **Default OFF.** |
| `/crosstalk:request <target> <msg>` | Mail a live peer; it acts and replies at its next turn boundary |
| `/crosstalk:quiet-ask <target> <q>` | A read-only fork of the peer's context answers; the peer never sees it |
| `/crosstalk:observe <target>` · `unobserve` | Standing grant: consult a peer on your own initiative (read-only, surfaced) |
| `/crosstalk:chatty <target>` | Mutual pair: both may quiet-ask + send short updates |
| `/crosstalk:watch` | Park a background wake watcher so incoming mail wakes THIS session while it's idle (no keypress) |
| `/crosstalk:orchestrator` · `enlist` · `adopt` · `team` · `release` | Hub-and-spoke fleets (spokes self-register and report up) |
| `/crosstalk:status` · `list` · `name` · `read` · `stop` · `clean` | State, targets, aliases, transcript mining, teardown, janitor |

### Stay reachable while idle

Crosstalk's one delivery gap used to be the **idle** session — one sitting at its prompt with nobody typing sees incoming mail only when its human comes back and presses a key. `/crosstalk:watch` closes it: park a **wake watcher** and the session picks up incoming mail within ~30 seconds and acts on it, no human needed. You rarely run it by hand — when a session ends a turn with no watcher parked, a hook nudges it to park one, so the behavior maintains itself. It costs **zero tokens** while parked (a background task that simply waits), and the `ENABLED` switch still governs everything: it changes only *when* authorized mail lands, never *whether* sessions talk.

Full command reference, safety model, and design are in the
[repository README](https://github.com/BlackBox-ai-lab/plugins) and
[`SECURITY.md`](./SECURITY.md).

## Safety

Built after a real incident (unrelated sessions emergently mailed each other unprompted).
Layered lockdown: default-OFF master switch, no model auto-invocation of action verbs, never
self-initiate (standing grants are read-only only), and a rolling-window rate limit on
autonomous delivery. No network, no credentials, no privilege escalation — see `SECURITY.md`.

## License

MIT

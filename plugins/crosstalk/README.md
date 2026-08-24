# Crosstalk

Claude Code can now message its own sessions. Crosstalk 2.0 is the layer on top: the silent
read-only consult of a peer's context, briefed requests instead of one-liners, operator-armed
standing grants, and hub-and-spoke fleet bookkeeping. **Every action verb runs only on your
explicit command.**

**Requires Claude Code 2.1.224 or newer** (native `ListAgents` / `SendMessage`) and `jq` on PATH.

## What the harness already gives you

Cross-session messaging is native. Sessions on one machine — plus cloud and Remote Control
sessions — discover each other by name, and a message delivered to an **idle** session wakes it:
it reads the message and acts, with nobody at the keyboard. Delivery is consent-gated by
permission mode, and the receiving human decides the policy. None of that is crosstalk's code,
and none of it needs this plugin.

| Capability | How it works natively |
|---|---|
| **Discover** | The `ListAgents` tool lists addressable sessions as `name [ref]`, with busy/idle status |
| **Send** | The `SendMessage` tool: `{"to": "<name>", "message": "…"}` — add ` [ref]` only to disambiguate |
| **Wake an idle peer** | An idle receiver wakes on delivery and processes the message; no keypress |
| **Consent gate** | Auto-delivers within the same permission-mode class; otherwise the receiver's human sees *Deliver / Deny*. Set `crossSessionInbound` to `accept`, `hold`, or `refuse` in settings (a project or managed policy may only tighten it) |
| **Names** | `claude --name <n>` at launch, `/rename <n>` in-session, or derived from the cwd |

## What crosstalk adds

| Verb | What it does |
|---|---|
| `/crosstalk:request <target> <msg>` | Resolves the target, **writes the briefing** (the ask, absolute paths, a ≤8-line summary on top, a reply address), sends it, and tells you what went out |
| `/crosstalk:quiet-ask <target> <q>` | A throwaway read-only fork of the peer's context answers. The peer never sees it, does nothing, and can be **idle or closed** |
| `/crosstalk:read <target> [q]` | Mines a session's transcript via a cheap subagent — closed sessions included |
| `/crosstalk:observe <target>` · `unobserve` | Standing grant: this session may quiet-ask that peer **on its own initiative** — read-only, always surfaced |
| `/crosstalk:chatty <target>` | Mutual pair: both sides may quiet-ask each other and send short delta updates |
| `/crosstalk:orchestrator` · `enlist` · `adopt` · `team` · `release` | Hub-and-spoke fleets: roster, externalized team state, succession across handoffs |
| `/crosstalk:list` · `status` · `stop` · `clean` | Live sessions annotated with their crosstalk roles · this session's state · teardown · janitor |

The through-line: native messaging is a *channel*. Crosstalk is the **protocol** — who may talk
to whom on their own initiative, what a message should contain, how to ask a question without
disturbing anybody, and how a fleet keeps its bookkeeping outside every repo.

## Install

```
/plugin marketplace add BlackBox-ai-lab/plugins
/plugin install crosstalk@blackbox-ai-labs
```

Prefer to read the code first, or track a fork? Clone and install from the working copy instead —
same result:

```
git clone https://github.com/BlackBox-ai-lab/plugins.git blackbox-plugins
/plugin marketplace add ./blackbox-plugins
/plugin install crosstalk@blackbox-ai-labs
```

Working from a private fork, or added as a collaborator on a private repo? The SSH source form is
supported and uses your existing git credentials:

```
/plugin marketplace add git@github.com:BlackBox-ai-lab/plugins.git
```

Both work as plain CLI too, without the leading slash (`claude plugin marketplace add …`,
`claude plugin install …`), if you'd rather script it.

**Then run `/reload-plugins`** — that activates it in your current session, so you can keep going
without restarting. The 15 verbs load as `/crosstalk:*`, and one `UserPromptSubmit` hook is
registered automatically; there is nothing to wire by hand and nothing to add to your settings.
Confirm with `claude plugin details crosstalk@blackbox-ai-labs`, which should report **15 skills
and 1 hook**.

### First run

Nothing to switch on: the channel is the harness's, and crosstalk's own verbs each wait for your
command.

```
/crosstalk:list                          # who is addressable, and what they are to you
/crosstalk:quiet-ask <name> what's the state of the migration?
/crosstalk:request  <name> take the failing test in <abs-path> and fix it
```

Watch the difference. `quiet-ask` returns an answer and the peer's window never moves.
`request` lands in the peer's context — if it is idle it **wakes up** and gets to work; if its
permission mode differs from yours, its human is asked to Deliver or Deny first.

To take grants back down: `/crosstalk:stop` (this session's pair and standing grants).

### Upgrading

Two commands, then a restart — the marketplace refresh alone does not update the plugin:

```
claude plugin marketplace update blackbox-ai-labs
claude plugin update crosstalk@blackbox-ai-labs
```

## Upgrading from 1.x

1.x carried its own mail transport. The harness does that now, so the transport is gone.

- **Hooks changed.** 1.x registered `UserPromptSubmit` **and** `Stop`; 2.0 registers one
  `UserPromptSubmit` hook (the role/grant reminder). Restart or `/reload-plugins` after
  updating, or the old Stop hook stays live in the session.
- **Run `/crosstalk:clean`.** It offers to remove the legacy `~/.claude/session-mail/` directory —
  mailboxes, the `ENABLED` switch, `names.json` — after asking. 2.0's state lives in
  `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/` and nothing is read from the old path.
- **`on` / `off` / `name` are gone.** The master switch is replaced by the harness's
  `crossSessionInbound` setting (`accept` | `hold` | `refuse`) — you now control what reaches
  *you* rather than what the machine may send. Aliases are replaced by native names: `/rename <n>`,
  or `claude --name <n>` at launch.
- **Targets are names now.** A short id or full UUID still resolves, but the natural address is
  the session's name.
- **Rate limiting is gone** with the transport it bounded, and there is no `forward` pointer:
  succession works by the successor renaming itself to the predecessor's alias.

## Safety

Crosstalk introduces no network surface, no credentials, and no privilege escalation. Its
residual surface is the read-only consult fork, the flow of context between sessions, standing
grants, cleartext state at rest, and one hook — each covered candidly in
[`SECURITY.md`](./SECURITY.md). The agency rules are the plugin's identity and are not decorative:
action verbs are `disable-model-invocation: true`, a session never self-initiates a message, and
the only sanctioned self-initiation is a **read-only** consult of a peer you explicitly drew in.

Full mechanics: [`references/protocol.md`](./references/protocol.md).

## License

MIT

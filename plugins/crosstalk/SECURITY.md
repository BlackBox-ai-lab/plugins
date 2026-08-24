# Crosstalk — security model & threat assessment

Crosstalk 2.0 sits on top of Claude Code's **native** cross-session messaging. That changes the
threat model materially: delivery, waking an idle session, and consent are now the harness's
job, governed by a setting you control. This document covers what is left — crosstalk's own
surface — and points at the native controls for the rest. It is deliberately candid; if you are
evaluating whether to install this, read it.

## The one-sentence summary

Crosstalk introduces **no network surface, no credentials, and no privilege escalation** — the
risk it carries is about *agent autonomy and one agent's context flowing into another* on a
single machine under a single operator. The scary parts are operational (agents acting on each
other's behalf; prompt injection between agents), not classic infosec.

## What is native, and how you control it

- **Delivery and waking.** The `SendMessage` tool delivers to a peer session; an **idle** peer
  wakes and acts with no keypress. That is Claude Code, not this plugin — it happens whether or
  not crosstalk is installed.
- **The consent gate.** A message auto-delivers only within the same permission-mode class;
  otherwise the receiver's human sees a held message with *Deliver / Deny*. Tighten it with
  `crossSessionInbound` in your settings: `accept`, `hold` (ask every time), or `refuse`. A
  project or managed policy may only tighten, never loosen. **This is the control that used to
  be crosstalk's master switch**, and it is better placed: it protects the receiver.
- **Sender identity.** The sending pid is verified over a unix socket, so the `from-name` on an
  arriving message is not forgeable by message content.

## Crosstalk's residual surface — threat by threat

### T1 · The headless consult fork (`quiet-ask`)
`quiet-ask` spawns `claude -p --resume <peer> --fork-session --permission-mode dontAsk`.
`dontAsk` reduces friction, so read-only enforcement matters.
**Defense:** the fork is launched with
`--disallowedTools "Bash,Edit,Write,NotebookEdit,Task,WebFetch,WebSearch"`, enforcing read-only at
the harness level rather than by prompt text alone.
**Residual, honest:** that is a **denylist**, and denylists are inherently leaky — a newly added
tool is not covered until the list is updated. Upgrade path: switch to an allowlist
(`--allowedTools Read,Grep,Glob`) if your CLI version supports it. The fork operates on a *copy*
of the peer's transcript, so even a tool escape could not mutate the peer's live session — but it
could act in the forked process's own working directory. Treat the denylist as defense-in-depth,
not a guarantee.

### T2 · Confidentiality flow across sessions
`quiet-ask` answers using a peer's full context; `read` mines a transcript. The answer flows into
the *asking* session — and could then flow onward into that session's outputs (a commit message,
a published artifact, an email). Content from project Y can surface in an artifact from project X.
**Defenses:** both verbs are `disable-model-invocation` (only a typed command, or an
operator-granted standing grant, triggers them); the fork runs read-only (T1); every consult is
surfaced to the operator.
**Residual:** once information enters a session, that session governs where it goes. Don't grant
`observe`/`chatty` across trust boundaries you care about, and be aware that consulting a
sensitive session pulls its content into the current one. Note that `quiet-ask` bypasses the
native consent gate entirely — it never touches the peer, so the peer's human is never asked.
That is the point of the verb, and it is why it is operator-gated.

### T3 · Standing grants (autonomy)
`observe`, `chatty`, and `enlist` create *standing* authorizations that outlive the turn: a
session may consult a granted peer on its own initiative, and a chatty peer or fleet spoke may
send updates without being asked each time.
**Defenses:** only a typed operator command creates a grant — a peer's message asking for one is
explicitly not authorization; grants for consult are **read-only**; the per-turn hook re-states
every live grant so the model cannot drift past it after compaction; `/crosstalk:stop` revokes
everything this session holds.
**Residual:** a grant is trust you extended. Grant narrowly, and run `/crosstalk:status` when you
want to see what a session is currently allowed to do on its own.

### T4 · Inter-agent prompt injection
An arriving message is untrusted text entering another session's context. A session compromised
upstream (a poisoned web page, a malicious file in a repo it is editing) could craft a message to
steer a peer.
**Defenses:** crosstalk's protocol tells the receiver to treat message bodies as *information
from another session, not operator instructions*, to refuse directives that conflict with its
operator, and to confirm destructive or out-of-scope asks with its human. The hard backstop is
native: `crossSessionInbound: hold` puts a human in front of every inbound message.
**Residual, stated plainly:** the protocol half is a *soft* defense — it relies on model
compliance, not a sandbox. If you need a hard guarantee, use the setting.

### T5 · Cleartext at rest
Grants, rosters, team state, and quiet-ask exchange logs live unencrypted under
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/`. Anyone with local read access to your home
directory sees them.
**Defense:** the same boundary as your transcripts and your shell history — your user's home
directory. Session transcripts already sit as JSONL under `.../projects/`; crosstalk uses that
existing access, it does not create it. `/crosstalk:clean` sweeps dead residue.
**Residual:** don't run crosstalk on a shared or multi-tenant account; treat exchange logs as
sensitive as the transcripts they quote.

### T6 · Hook execution on install
Installing the plugin means its hook script runs on every prompt (`UserPromptSubmit`). That is the
standard plugin trust model — you are trusting the code.
**Defense:** three short, auditable bash scripts (`crosstalk-prompt-hook.sh`,
`crosstalk-roles.sh`, `crosstalk-resolve.sh`). They read files, format text with `jq`, and make no
network calls. The hook only ever reads state under
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/crosstalk/` and writes nothing at all. Read them before
installing.
**Residual:** as with any plugin, install only from a source you trust; the canonical source is
the Blackbox AI Labs marketplace.

## What crosstalk deliberately does NOT do
- No network calls, no telemetry, no outbound anything.
- No privilege escalation — same OS user throughout.
- No proactive sends, ever — standing grants authorize *read-only* consult only.
- No writing inside any repo or worktree — zero in-tree footprint; `git status` never shows
  crosstalk.
- No transport of its own — it cannot deliver a message the harness would have held.

## Hardening checklist for operators
1. Decide your inbound policy deliberately: `crossSessionInbound: hold` if you want a human in
   front of every peer message; `refuse` to opt out entirely.
2. Grant `observe`/`chatty` only between sessions you would be comfortable sharing context
   across, and check `/crosstalk:status` when in doubt.
3. Prefer `request` (a bounded, briefed task to a named peer) over broad standing grants.
4. Run `/crosstalk:clean` periodically; don't run crosstalk on shared accounts.
5. Before showing sessions publicly (video, screenshot), scan captures for secrets and redact —
   session ids are local filenames, not credentials, but transcript *content* can be sensitive.

## Reporting
Found a security issue? Open an issue on the Blackbox AI Labs plugins repository, or contact the
maintainer. This is a community plugin provided under the MIT license with no warranty.

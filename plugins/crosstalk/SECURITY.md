# Crosstalk — security model &amp; threat assessment

Crosstalk lets Claude Code sessions on one machine message and consult each other. That is genuinely useful and genuinely powerful, and power in an agent tool deserves an honest security accounting. This document is that accounting: what the tool can and cannot do, what could go wrong, what defends against it, and what residual risk remains. It is deliberately candid — if you are evaluating whether to install or enable this, read it.

## The one-sentence summary

Crosstalk introduces **no network surface, no credentials, and no privilege escalation** — every risk it carries is about *agent autonomy and one agent influencing another within a single trusted machine under a single operator*. The scary parts are operational and philosophical (agents acting on each other's behalf; prompt injection between agents; emergent behavior), not classic infosec.

## Trust model &amp; scope

- **One machine, one user.** All state lives in files under `~/.claude/session-mail/`. Every session runs as the same local OS user. Crosstalk is local IPC over the filesystem — there is no server, no socket, no outbound request, nothing leaves the machine.
- **No new confidentiality boundary is created.** Session transcripts already sit as world-readable-to-your-user JSONL under `~/.claude/projects/`. Any process you run can already read them. Crosstalk *uses* that existing access ergonomically; it does not create it. Anyone who can run crosstalk could already `cat` the same files directly.
- **Not credentials.** Session ids, mailbox paths, and transcript filenames are local filenames. There is no remote endpoint where knowing one grants access; `--resume` requires your machine and your logged-in account. Showing a session id on screen (e.g. in a video) exposes nothing loginnable.

## What could go wrong — threat by threat

### T1 · Autonomous action at turn end (the core power)
The Stop hook delivers mail at the end of a *working* session's turn and continues the conversation so the session acts on it — **no human keypress**. This is the feature and the risk: one session can cause another to do work unattended.
**Defenses:** default-OFF master switch; only explicitly-*sent* mail is ever delivered (a session never self-initiates a send); a `request` obligates only a *reply*, not arbitrary action; a rolling-window rate limit (15 autonomous deliveries per 300 s per session) bounds any back-and-forth; past the cap, mail waits for a human keypress.
**Residual:** a working session will act on delivered mail without you watching. Mitigate by treating `request` as "assign a peer a task," not "remote-control it," and keeping the switch off when you're not orchestrating.

### T2 · Inter-agent prompt injection
Delivered mail is untrusted text that enters another session's context. A session that has been compromised upstream (a poisoned web page it fetched, a malicious file in a repo it's editing) could craft mail to steer a peer.
**Defenses:** injected mail is explicitly framed as *information from another session, not your operator's instructions*; the protocol tells the receiver not to follow directives that conflict with its operator and to confirm destructive/out-of-scope asks with its human first.
**Residual, stated plainly:** this is a *soft* defense — it relies on model compliance, not a hard sandbox. Injection resistance is best-effort. The hard backstops are the ones that don't depend on the model reasoning correctly: default-off, the rate limit, and no-proactive-send.

### T3 · Confidentiality leakage across sessions
`quiet-ask` answers a question using a peer's full context; `read` mines a transcript. The answer flows into the *asking* session — and could then flow onward into that session's outputs (a commit message, a published artifact, an email). So content from project Y can surface in an artifact from project X.
**Defenses:** both are `disable-model-invocation` (only a typed command, or an operator-granted standing grant, triggers them); the quiet-ask fork runs read-only (see T4); every consult is surfaced to the operator.
**Residual:** once information enters a session, that session governs where it goes. Don't grant `observe`/`chatty` across trust boundaries you care about, and be aware that consulting a sensitive session pulls its content into the current one.

### T4 · The headless consult fork
`quiet-ask` spawns `claude -p --resume <peer> --fork-session --permission-mode dontAsk`. `dontAsk` reduces friction, so read-only enforcement matters.
**Defense:** the fork is launched with `--disallowedTools "Bash,Edit,Write,NotebookEdit,Task,WebFetch,WebSearch"`, enforcing read-only at the harness level rather than by prompt text alone.
**Residual, honest:** that is a **denylist**, and denylists are inherently leaky — a newly added tool would not be covered until the list is updated. Upgrade path: switch to an allowlist (`--allowedTools Read,Grep,Glob`) if the CLI supports it in your version. The fork operates on a *copy* of the peer's transcript, so even a tool escape could not mutate the peer's live session — but it could act in the forked process's own working directory. Treat the denylist as defense-in-depth, not a guarantee.

### T5 · Emergent / unwanted adoption (this actually happened)
Within a day of the original skill shipping, unrelated sessions emergently adopted it and mailed each other unprompted, including a one-to-two fan-out. This is not hypothetical — it is why the lockdown exists.
**Defenses (the whole lockdown):** default-OFF; `disable-model-invocation: true` on every action verb (the skill only loads on a typed command); explicit "never self-initiate" agency rules; the rate limit. The only sanctioned self-initiation is *read-only* consult of a peer the operator explicitly drew in via `observe`/`chatty`/`enlist` — never a proactive send.
**Residual:** if you turn the switch on and leave many capable sessions running, you are trusting the agency rules. Keep the switch off by default; that is the design intent.

### T6 · Cleartext at rest
Mail bodies, exchange logs, rosters, and team-state live unencrypted under `~/.claude/session-mail/`. Anyone with local read access to your home directory sees all inter-session traffic.
**Defense:** same boundary as your transcripts and your shell history — it's your user's home directory. `/crosstalk:clean` sweeps dead residue.
**Residual:** don't run crosstalk on a shared/multi-tenant account; treat the mailboxes as sensitive as the transcripts they summarize.

### T7 · Hook execution on install
Installing the plugin means its hook scripts run on every prompt (`UserPromptSubmit`) and turn end (`Stop`). That is the standard plugin trust model — you are trusting the code.
**Defense:** the four scripts are short, auditable, and do only file moves plus `jq` formatting; they make no network calls and touch nothing outside `~/.claude/session-mail/`. Read them before installing.
**Residual:** as with any plugin, install only from a source you trust; the canonical source is the Blackbox AI Labs marketplace.

## What crosstalk deliberately does NOT do
- No network calls, no telemetry, no outbound anything — purely local file IPC.
- No privilege escalation — same OS user throughout.
- No proactive sends, ever — standing grants authorize *read-only* consult only.
- No waking of idle sessions — there is no mechanism to make an idle session act (a tmux-based option was designed and deliberately **not** shipped; see `docs/TMUX-WAKE.md`).
- No writing inside any repo or worktree — zero in-tree footprint; `git status` never shows crosstalk.

## Hardening checklist for operators
1. Leave the master switch **OFF** except when actively coordinating sessions.
2. Grant `observe`/`chatty` only between sessions you'd be comfortable sharing context across.
3. Prefer `request` (a bounded task to a live peer) over broad standing grants when you can.
4. Run `/crosstalk:clean` periodically; don't run crosstalk on shared accounts.
5. Before showing sessions publicly (video, screenshot), scan captures for secrets and redact — session ids aren't credentials, but transcript *content* can be sensitive.

## Reporting
Found a security issue? Open an issue on the Blackbox AI Labs plugins repository, or contact the maintainer. This is a community plugin provided under the MIT license with no warranty.

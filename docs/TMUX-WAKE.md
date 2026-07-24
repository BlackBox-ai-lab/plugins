# Reserved design: tmux-based idle wake & fleet spawning

**Status: designed, prototyped, deliberately NOT shipped.** Removed from the plugin at v1.2.0 to keep the operator's environment simple (no tmux dependency). This document preserves the complete design so it can be reinstated if the need materializes. Nothing in the shipped plugin depends on anything here.

> **Superseded for the common case.** The `/crosstalk:watch` **wake watcher** now ships and closes the everyday idle gap *without tmux*: a session parks a `run_in_background` Bash task before idling, and that task's completion re-invokes the session when mail lands. That is a real harness mechanism the "no native mechanism" analysis below did not account for — it is not a timer hook (there still is none), it is a background-task completion notification. The tmux design here remains reserved only for what the watcher does **not** cover: spawning a fleet of builders, and waking a spoke that never parked a watcher (one session forcing another to act). Read the paragraph below with that correction in mind.

## The problem this solves

Doc-verified against code.claude.com: **no hook event is timer- or idle-triggered.** The Notification hook fires when a session is *already* waiting but cannot inject context or start a turn (only UserPromptSubmit, PostToolUse, PostToolBatch, and Stop support `additionalContext`); and no CLI/socket/SDK surface injects a prompt into a running interactive session. (What the analysis missed, and the `/crosstalk:watch` watcher now exploits: the completion of a `run_in_background` Bash task *does* re-invoke an idle session — a wake signal without a timer hook. That closes the common idle gap; the remaining hole is below.)

Consequence for crosstalk: mail for a **working** session lands at its next turn end (Stop hook — no keypress). An **idle** session that parked a watcher wakes on its own. The remaining hole is narrow — a fleet spoke that finished all its work, sits idle, and **never parked a watcher**, when the hub wants to hand it *new* work unattended.

**The shipped position: park a watcher, else accept the residual gap.** Spokes in an active fleet are usually working (turn-end delivery) or can park a watcher (idle wake), so both common cases are covered. For a spoke that did neither, the escalation path is tail-read → quiet-ask → tell the operator.

## The reserved solution: tmux as the actuator

tmux is a session multiplexer that runs *inside* any terminal. Its `send-keys` command can type into any pane programmatically — which is exactly the keypress an idle session is waiting for. Claude Code is never modified or bypassed; the UserPromptSubmit hook fires as if the human typed.

```bash
tmux send-keys -t '%12' 'crosstalk: mailbox has pending mail - check and act on it' Enter
```

### Component 1: `/crosstalk:wake <alias>` (hub-initiated nudge)

- **Enrollment:** `enlist` additionally records `$TMUX_PANE` (set inside tmux) into the roster — an extra roster column `<tmux-pane|->`. A spoke without a pane is simply "not wakeable."
- **Procedure:** find the spoke's pane in the roster; verify it still exists (`tmux list-panes -a -F '#{pane_id}' | grep -qx '<pane>'` — gone → mark not-wakeable, tell the user); `send-keys` the nudge; confirm to the user which spoke was woken and why.
- **Safety gating (non-negotiable if reinstated):** waking makes a session burn a turn its user didn't type. Gate on the ENABLED master switch; only roster-enrolled, pane-recorded targets; only the operator's explicit command or the orchestrator's surfaced staleness escalation.

### Component 2: `/crosstalk:fleet <names...>` (spawn self-enlisting builders)

One command spawns N builders, each in a named tmux window, pre-prompted to self-register:

```bash
tmux new-session -d -s fleet 2>/dev/null || true
tmux new-window -t fleet -n <alias> -c <workdir> \
  "claude \"/crosstalk:enlist <hub-alias> '<task>'\""
```

Each builder's first action is enlistment — it records its own sid, git context, and pane (wakeable from birth). Optional `--worktrees`: create each builder's tree as a repo **sibling** (`git -C <repo> worktree add ../<repo>-wt-<alias> -b <alias>/work`), marked `fleet:yes` in the roster; `/crosstalk:release` then owns cleanup (remove only when clean and merged; dirty → surface, never delete). This was the ONLY path by which crosstalk ever created worktrees; with fleet unshipped, crosstalk creates none, ever.

### Component 3 (investigated, rejected regardless): FileChanged auto-wake

The `FileChanged` hook event *can* fire while a session is idle and *can* run side-effect commands (which could include `send-keys` at the session's own pane) — but it watches **filenames in the project directory only**. Exploiting it would require the sender to touch a marker file inside the recipient's repo, violating the zero-in-tree-footprint invariant. Rejected even for the tmux future.

### Component 4 (alternative, no Claude Code involvement): external watcher service

A tiny systemd **user** service running `inotifywait -m ~/.claude/session-mail/*/new/` that maps session id → tmux pane (from the roster) and fires `send-keys` on mail arrival. Fully automatic wake, zero footprint, cleanly separable from the plugin — but it's a daemon to install, monitor, and debug. Reserve for a genuine unattended-fleet need.

## Why it was backed out

The operator doesn't use tmux; adopting a multiplexer *only* to close an edge-case delivery gap inverts the cost/benefit. The plugin degrades gracefully without it, and every other capability is terminal-agnostic. tmux earns its learning curve only when unattended fleets become routine and the idle gap demonstrably bites.

## How to reinstate

1. Restore the two skills (`skills/wake/`, `skills/fleet/`) from git history: `git log --diff-filter=D --oneline -- 'plugins/crosstalk/skills/wake'` → checkout from the commit before removal (shipped at v1.1.0, removed at v1.2.0).
2. Re-add the roster columns (`tmux-pane`, `fleet`) in `enlist`/`adopt`, the "wakeable" line in `team`, the wake rung in `orchestrator`'s staleness escalation, and the fleet-worktree cleanup step in `release`.
3. Bump the plugin version; note tmux as an optional prerequisite in the README.

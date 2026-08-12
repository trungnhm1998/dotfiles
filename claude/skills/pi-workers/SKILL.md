---
name: pi-workers
description: >-
  Delegate implementation, review, and verification tasks to pi coding agents running in
  Orca terminals, so work fans out onto a separate model/quota while the controller keeps
  its context for coordination. Use whenever the user says "delegate to pi", "pi worker",
  "pi agent", "use pi", "fan out to agents", "external agent worker", "run this through
  another harness", or asks to execute a plan with non-Claude workers (e.g.
  subagent-driven development with pi implementers/reviewers). Also use when choosing
  WHICH lane a task belongs in: pi worker vs built-in subagent. Covers the
  dispatch-file protocol, completion detection, capability routing (pi has no MCP), and
  live-repo git safety. The same protocol extends to other TUI harnesses (codex,
  opencode, grok) — pi is the first-class worker.
---

# pi Workers

Drive pi (pi.dev — a minimal Read/Write/Edit/Bash harness) as a worker from a controller
session. The worker runs on its own model and quota, in the real repo, with its own
context window; the controller keeps its context for coordination. Proven shape: a
controller ran 3 pi implementers + 4 pi reviewers through a 5-task plan with zero
shell-parse failures and zero lost runs.

This protocol is controller-agnostic (Claude Code, pi itself, or any harness that can run
the Orca CLI) and worker-generalizable — codex/opencode/grok accept the same shape — but
pi is the first-class worker and the one these notes are verified against.

**Prerequisite:** the Orca CLI manages the terminals. Load the `orca-cli` skill first and
run `orca skills get orca-cli` for the version-matched command reference — this skill only
covers the worker protocol, not Orca itself.

## Choose the lane before dispatching

Not every task can go to a pi worker. Route by capability, not preference:

| Task needs | Lane |
|---|---|
| Files, shell, tests, git — anything a plain CLI can do | pi worker |
| MCP tools (Unity Editor, browser MCP, any `mcp__*`) | A harness with MCP (e.g. a built-in Claude subagent) — **pi has no MCP client** (verified v0.84.1); it will come back BLOCKED no matter how the dispatch is worded |
| The controller session's conversation context | Built-in fork/subagent — pi workers start cold |

Two rules that keep mis-routing cheap:

- Put an escape hatch in every dispatch: "if you cannot do X with the sanctioned tools,
  report Status: BLOCKED immediately — do not improvise another path." A worker that can't
  comply then fails loudly in minutes instead of doing damage (e.g. hand-editing a Unity
  prefab YAML because the MCP route was unavailable).
- When a worker reports BLOCKED on a capability gap, fall back to a harness that has the
  capability and note the lane change — it changes who reviews what.

## The protocol: a dispatch file and a report file

Never send a multi-paragraph brief through `terminal send` — the text is retyped into the
worker's shell and every quoting/here-string trap in that shell applies to your prose.
Instead, the pair of files IS the protocol:

1. **Controller writes** `<workspace>/task-N-dispatch.md` — everything the worker needs.
2. **Controller sends one short line**: `Read the file <path> and execute it exactly. It
   is your task dispatch.`
3. **Worker writes** `<workspace>/task-N-report.md` — full evidence, and prints a short
   status in the terminal.

A dispatch file that works contains, in order:

- One line of project context (where this task fits — workers start cold).
- Pointer to the requirements (a brief file, spec section, or inline) introduced as
  "read this first — it is your requirements."
- Binding constraints, including any overrides of the requirements ("the brief says X;
  OVERRIDE: do Y — this governs").
- Tooling rules pi needs (see Worker hygiene below).
- Git safety block (see below) if the worker will commit.
- The escape-hatch line and the report contract:

```markdown
## Report
Write your full report to: <workspace>/task-N-report.md
(what you did, evidence: commands + output, files changed, self-review, concerns)
Then print in this terminal ONLY (under 15 lines):
- Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- Commit SHA + subject (if you committed)
- One-line test/check summary
- Concerns, if any
```

The four statuses matter: DONE proceeds, DONE_WITH_CONCERNS means read the concerns before
proceeding, BLOCKED/NEEDS_CONTEXT mean something must change (context, lane, or task size)
— never re-send the same dispatch unchanged.

## Spawn, dispatch, wait

```powershell
# same-checkout work (worker shares your working tree)
$h = orca terminal create --worktree active --title "task3-impl" --command "pi" --json |
     ConvertFrom-Json | % { $_.result.terminal.handle }

# isolated work: orca worktree create --name task3 --agent pi --prompt "..." instead

orca terminal wait --terminal $h --for tui-idle --timeout-ms 60000 --json   # startup only
orca terminal send --terminal $h --text "Read the file <dispatch-path> and execute it exactly. It is your task dispatch." --enter --json
```

`--for tui-idle` has exactly one sound use: waiting for the TUI to come up **before**
sending. It is unsound as a completion signal — it fires in the gap between the keystrokes
being accepted and the run starting to stream.

pi auto-loads `~/.pi/agent/AGENTS.md`, the repo's `AGENTS.md`/`CLAUDE.md`, and repo
`.agents/skills/`, so project conventions arrive without restating them in the dispatch.

## Detect completion by artifact, never by terminal text

Poll for the report file the worker was told to write. It is monotonic and it means "done";
terminal text means neither.

```powershell
$deadline = (Get-Date).AddMinutes(10)
while ((Get-Date) -lt $deadline) {
  if (Test-Path $report) { break }
  Start-Sleep -Seconds 20
}
if (-not (Test-Path $report)) { <# read terminal tail to DIAGNOSE, not to conclude #> }
```

Why not grep the terminal for `Status: DONE`? Two lived failures:
- The dispatch line the controller just sent contains the status vocabulary and is echoed
  in the buffer — the poll fires on the prompt it just typed.
- Orca scrollback holds previous runs — a `LastIndexOf` marker search happily returns the
  *previous* task's verdict. If the buffer must be read, slice it forward from this
  dispatch's unique command echo first.

On timeout, read the tail (`orca terminal read --terminal $h`) to see whether the worker is
asking a question (answer it with another `terminal send`), thinking, or wedged. For
liveness vs progress on long runs, and pi's session-jsonl signal, see `references/pi.md`.

## Git safety in a live repo

A worker in `--worktree active` shares one index with whatever the human has staged. A
worker that "cleans up" with `git reset` or sweeps with `git add -A` destroys staging state
that was never its to touch. Every dispatch that commits must:

- Name the **exact paths** the worker may `git add` — nothing else.
- Forbid `git add -A`, `git add .`, and bare `git reset`.
- Name what must never be committed (scratch dirs, plan files, unrelated dirty files —
  list them; the worker cannot tell drift from work).
- State the commit message (or its convention) — including "no AI-attribution trailers"
  if that is house style.

## Fix rounds and cleanup

- Review findings go back to the **same terminal** — the worker's context is intact and a
  resume is one `terminal send` with the findings verbatim. Spawn a fresh worker (or
  escalate model/harness) only after repeated failed rounds.
- A killed worker is context-lost even if its session id is reused — write recovery
  prompts to stand alone (restate what is already done). Details in `references/pi.md`.
- When the work is merged: close the worker terminals (`orca terminal close`), and update
  the card (`orca worktree set --worktree active --comment "..." --workspace-status ...`)
  so the Orca UI reflects reality.

## Worker hygiene (put these lines in dispatches)

- **File writes:** "Use your built-in write/edit tools for all file writes. Never use bash
  heredocs, `cat >` redirection, or `echo >`." (pi's bash tool hangs forever on heredocs on
  Windows — the run burns CPU and never returns.)
- **Questions:** "If anything is unclear or contradicts the code, ask in this terminal
  before starting. Don't guess." Then actually watch for questions on the first poll.
- **Reviews:** pi workers make good reviewers too — hand them the brief, the implementer's
  report, and a pre-generated diff file; instruct read-only ("do not mutate the working
  tree, index, HEAD, or branch state").

## Deeper pi knowledge

Read `references/pi.md` before running pi in `-p` print mode, debugging a stuck or
suspiciously fast worker, or choosing worker models. It covers: print-mode quoting traps,
session-jsonl monitoring, the liveness-vs-progress two-signal rule, provider-death
failover, session-id resume semantics, and the mini-executes/big-model-reviews split.

## Other worker harnesses

codex, opencode, and grok accept the same spawn/dispatch/report protocol
(`orca terminal create --command "codex"` or `orca worktree create --agent codex`). Their
capability surfaces differ from pi's — before routing MCP- or web-dependent tasks, check
the harness's tool surface or dispatch a cheap probe task first. First-class support notes
for them will land here as they get the same lived verification pi has.

---
name: pi-workers
description: >-
  Delegate implementation, review, and verification tasks to pi coding agents running in
  Orca terminals, so work fans out onto a separate model/quota while the controller keeps
  its context for coordination. Use when the user says "delegate to pi", "pi worker",
  "fan out to agents", or "run this through another harness"; when executing a plan with
  non-Claude implementers/reviewers; or when choosing which lane a task belongs in
  (pi worker vs built-in subagent — pi has no MCP). Extends to codex/opencode/grok.
---

# pi Workers

Drive pi (pi.dev — a minimal Read/Write/Edit/Bash harness) as a worker from a controller
session. The worker runs on its own model and quota, in the real repo, with its own
context window; the controller keeps its context for coordination. The protocol is
controller-agnostic: any harness that can run the Orca CLI can be the controller.

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

## Pick the worker mode: interactive TUI or `pi -p` headless

pi runs two ways, and the choice is per task, not per session:

- **Interactive TUI** (`orca terminal create --command "pi"`) when the worker may need to
  ask questions, when fix rounds are likely (a resume is one `terminal send` into intact
  context), or when a human may watch or take over the terminal.
- **Headless print mode** (`pi -p`) for one-shot tasks with no expected back-and-forth:
  reviews, mechanical batches, report-only jobs, scripted pipelines. It exits when done
  (`orca terminal wait --for exit` works), takes per-task flags — `--model`/`--thinking`
  for role-sized brains, `-t`/`-xt` to clamp tools (e.g. strip `write,edit` from a
  reviewer), `--mode json` for parseable output, `--no-session` for ephemeral runs — and
  its quoting traps and monitoring live in `references/pi.md`.

When in doubt: TUI for implementers, `-p` for reviewers and batch mechanics.

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

1. **Controller writes** `task-N-dispatch.md` — everything the worker needs.
2. **Controller sends one short line**: `Read the file <path> and execute it exactly. It
   is your task dispatch.`
3. **Worker writes** `task-N-report.md` — full evidence, and prints a short status in the
   terminal.

Use **absolute paths** for both files. In `--worktree active` the worker shares your tree;
with `orca worktree create` the worker cannot see the controller's copy — write the
dispatch inside the new worktree (or commit it first).

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
Write your full report to: <absolute path>/task-N-report.md
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

Snippets are PowerShell (Orca terminals on Windows run pwsh) — on macOS/Linux substitute
`jq -r`, `test -f`, `sleep`.

```powershell
# same-checkout work (worker shares your working tree)
$h = orca terminal create --worktree active --title "task3-impl" --command "pi" --json |
     ConvertFrom-Json | % { $_.result.terminal.handle }

# isolated work: orca worktree create --name task3 --agent pi --prompt "..." instead
# (then write the dispatch inside that worktree — see above)

orca terminal wait --terminal $h --for tui-idle --timeout-ms 60000 --json   # startup only
orca terminal send --terminal $h --text "Read the file <dispatch-path> and execute it exactly. It is your task dispatch." --enter --json
```

`--for tui-idle` has exactly one sound use: waiting for the TUI to come up **before**
sending. It is unsound as a completion signal — it fires in the gap between the keystrokes
being accepted and the run starting to stream.

**Fan-out:** for independent tasks, spawn all the terminals and send all the dispatches
before waiting on any of them — keep a handle→report-path map and watch all the report
paths in one loop. Serialize only workers whose tasks touch the same files or the same
git index state (e.g. multiple implementers committing).

pi auto-loads `~/.pi/agent/AGENTS.md`, the repo's `AGENTS.md`/`CLAUDE.md`, and the repo's
`.agents/skills/` (visible in its startup banner), so project conventions arrive without
restating them in the dispatch.

## Detect completion by artifact, never by terminal text

Watch for the report file the worker was told to write. It is monotonic and it means
"finished"; terminal text means neither. Don't burn your own turn sleeping in a foreground
loop — background the watch and keep working (Claude Code: the `Monitor` tool, or a
background `until [ -f "$report" ]; do sleep 15; done` shell), with a deadline.

Why not grep the terminal for `Status: DONE`? Two lived failures:
- The dispatch line the controller just sent contains the status vocabulary and is echoed
  in the buffer — the poll fires on the prompt it just typed.
- Orca scrollback holds previous runs — a `LastIndexOf` marker search happily returns the
  *previous* task's verdict. If the buffer must be read, slice it forward from this
  dispatch's unique command echo first.

On deadline, read the tail (`orca terminal read --terminal $h`) to see whether the worker
is asking a question (answer it with another `terminal send`), thinking, or wedged. For
liveness vs progress on long runs, see `references/pi.md` — Monitoring a running worker.

**The report file means *finished*, not *correct*.** Before relaying a worker's outcome,
check the artifact yourself — `git status`, the diff, the files on disk. A worker once
moved every file correctly and reported "Moved: 0, every row a collision skip"; the report
was the only thing wrong.

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
suspiciously fast worker, monitoring a long run, or choosing worker models. It covers:
session-jsonl monitoring and the liveness-vs-progress two-signal rule, provider-death
failover, print-mode quoting traps, session-id resume semantics, the
mini-executes/big-model-reviews split, and the full flag surface worth squeezing
(tool clamps, thinking levels, json output, session forking, context slimming).

## Other worker harnesses

codex, opencode, and grok accept the same spawn/dispatch/report protocol
(`orca terminal create --command "codex"` or `orca worktree create --agent codex`). Their
capability surfaces differ from pi's — before routing MCP- or web-dependent tasks, check
the harness's tool surface or dispatch a cheap probe task first.

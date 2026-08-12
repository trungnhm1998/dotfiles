# pi as a worker — harness specifics

pi (pi.dev, Earendil) is a minimal four-tool harness (Read/Write/Edit/Bash) that
self-extends via skills and extensions. Everything here was lived on Windows 11
(pi 0.84.1, Orca 1.4.180); the traps are shell- and harness-level, so most transfer.

## Capability surface

- **No MCP client** (verified v0.84.1). No `mcp__*` tools exist in a pi session, ever.
  Route MCP-bound tasks (Unity Editor writes, browser MCP, etc.) to a harness that has
  MCP. A correctly written dispatch makes pi fail loudly: it reports
  `BLOCKED: MCP tools are not available` instead of improvising.
- **Instructions**: pi concatenates `~/.pi/agent/AGENTS.md` + parent-dir + cwd `AGENTS.md`
  (and honours `CLAUDE.md`), and auto-loads repo `.agents/skills/` — its startup banner
  lists them under `[Skills]`. Repo conventions and skills arrive without you restating
  them in the dispatch.
- **Approvals**: pi does not gate bash by default in this setup; `--approve/-a` only
  trusts project-local files. Workers have not hung on permission prompts, but watch the
  first poll's terminal tail on a new machine.

## Monitoring a running worker

These signals apply to any pi run, TUI or print mode:

- **Session log**: `~/.pi/agent/sessions/<cwd-slug>/<timestamp>_<session-id>.jsonl` —
  one JSONL record per thinking block and tool call. `LastWriteTime` rising = alive;
  the last line names the tool call it is inside. This is the only live window into a
  worker that prints nothing.
- **Liveness is not progress.** Monitor two numbers on long runs: the count of artifacts
  the task produces (progress, monotonic) and the session-jsonl mtime (liveness). Frozen
  mtime + incomplete count = stall; rising mtime + frozen count = stuck inside one tool
  call. One signal alone cannot distinguish slow from wedged.
- **Provider death looks like laziness.** pi's provider can start returning instant empty
  responses mid-pipeline: exit in seconds, `totalTokens: 0`, no content,
  `stopReason: "stop"`. Nothing says "provider error". Treat "finished suspiciously fast
  with no output" as a failover trigger: re-send with an explicit
  `--provider <alt> --model <id>`, and keep a second provider smoke-tested before long
  pipelines.
- **`--session-id` resumes only if the session file survived.** After `Stop-Process` on
  the worker, the same id prints `No project session found... creating a new session` —
  a restart, not a resume. When the provider died but the process wasn't killed, the same
  id DOES resume with earlier tool work intact. Either way, write the recovery prompt to
  stand alone: restate what is already done ("you already created the tag; reuse the
  numbers if you still have them, otherwise re-run"). It is free when the resume works
  and load-bearing when it does not.

## Interactive TUI mode (default — prefer this)

Covered in SKILL.md: `orca terminal create --command "pi"`, wait tui-idle for startup,
send the one-line dispatch pointer. Nothing long ever crosses the command line, so the
shell-quoting traps below simply do not arise.

## Print mode (`pi -p`) — when you want no TUI

```powershell
$cmd = "pi -p --session-id $sid -n task3-worker '@.superpowers/plan/task-3-dispatch.md' 'Execute the task now.'"
orca terminal send --terminal $handle --text $cmd --enter --json
```

- **PowerShell parses your command first.** `@"..."` is a here-string header in
  PowerShell; an attachment written `@".../dispatch.md"` aborts with
  `No characters are allowed after a here-string header...`. Single-quote attachments:
  `'@path/dispatch.md'`.
- **Silent until done.** `pi -p` prints nothing while running. Use the session log
  (above) as the live window, and the report file as the completion signal.

## Model per role

Observed split that works: **small/mini models execute mechanical work correctly but
report it wrongly** (a mover returned "Moved: 0, every row a collision skip" after moving
everything — its verification re-checked the source path, found it gone, called that a
collision). Larger models reconciled the same tables row-by-row without error. So:

- mini → mechanical execution lanes (moves, renames, transcription from a complete spec)
- larger model → review, reconciliation, anything whose *report* you must trust
- and never accept a move/rename outcome from the worker's own report — read
  `git status` or the disk. Verify against the artifact, not the claim.

## Bash tool hazards

- **Heredocs hang forever** on Windows: `cat > file << 'EOF'`, `cat`/`echo` redirection —
  the process never returns and burns CPU. The dispatch line "use your built-in write
  tool for all file writes; never bash heredocs or `>` redirection" eliminated this
  class entirely.
- pi's shell is persistent within a session — `cd` carries across tool calls; workers
  should use absolute or repo-relative paths.

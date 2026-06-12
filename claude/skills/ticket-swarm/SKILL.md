---
name: ticket-swarm
description: Use when multiple Jira tickets or bugs should be worked in parallel — "drain the backlog", "swarm these tickets", "fix these N tickets in parallel", or batch-shipping several small independent fixes at once.
---

# Ticket Swarm — parallel ticket-to-PR pipeline

One subagent per ticket, each in an isolated git worktree, each driving the full pipeline: root-cause → fix → tests → PR → ticket transition. The orchestrator coordinates; agents execute; the user gets one consolidated dashboard.

## Flow

1. **Collect + gate (the ONLY approval gate).** Take tickets from the user's list or Jira (atlassian MCP; e.g. assigned bugs by priority). Verify preconditions here: Jira MCP reachable, `gh auth status` good, SSH remote. Present the plan (ticket list, parallelism cap — default 3, branch naming `bugfix/<KEY>`): if the invocation already named the tickets that IS the approval — the plan is informational, proceed in the same turn; if the orchestrator picked tickets itself, wait for one confirmation. Either way agents never re-ask.
2. **Isolate.** The orchestrator creates all worktrees up front, before any dispatch — one per ticket. For Unity repos this is REQUIRED via the unity-worktree-setup skill — a naive worktree triggers a full Library reimport.
3. **Dispatch** one background subagent per ticket — FIFO in the given order (or Jira priority order), cap respected, queued tickets start as slots free. Default time budget: 30 min per agent, then it must return its best structured result. Each brief:
   - Root-cause with evidence (logs/code refs) — REQUIRED: superpowers:systematic-debugging. No confident root cause within budget → report `needs-human` with findings; never guess-fix.
   - Minimal surgical fix; run the relevant tests.
   - Commit (explicit paths only), push branch over SSH, open PR, comment the PR URL on the ticket, move ticket to Tech Review (per finish-ticket).
   - Return a structured result: `{ticket, status: green|needs-human|blocked, pr, root_cause_one_liner, notes}`.
4. **Dashboard.** When all agents return (or hit their time budget), output ONE table: ticket / status / PR / root cause. List anything needing the user's hands (Editor steps, permissions) explicitly.
5. **Capture.** One wiki-capture for the whole batch (root causes worth keeping) — not one per ticket.

## Invariants

- Agents never touch the main checkout or each other's worktrees.
- Cap parallel agents (default 3) — Unity imports and test runs contend for CPU/disk; more agents ≠ faster.
- A ticket needing scope decisions, unverifiable asset changes, or destructive ops → `needs-human`, not improvisation.
- Re-invocation converges: check existing branches/PRs/ticket states first; only do the missing work.

## Common mistakes

- Spawning all agents into the same checkout → corrupted state. Worktrees are non-negotiable.
- Letting an agent "try something" without a root cause → review burden explodes. `needs-human` is a valid outcome.
- Per-ticket ceremony spam — batch the wiki capture; keep ticket comments to the PR link.

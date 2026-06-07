# Handoff — templates & worked example

Loaded only when you need the fuller state-doc template or an annotated example. The kickoff-prompt template lives in SKILL.md.

## When you need a state doc (not just a prompt)
The kickoff prompt alone suffices for small/linear work. Add a separate **state doc** when the handoff carries detail the prompt should *link to, not contain*: multi-system architecture, a decision log with rationale, a long DONE/NEXT inventory, or risk register. The prompt then says "full state: docs/handoff/<file>.md" and stays lean.

## State-doc template
```markdown
# <Project> — Handoff <YYYY-MM-DD> → <next goal>

## Snapshot
- Repo(s) + path(s); branch; pushed? (ahead/behind origin); test count + status.
- One-paragraph "where we are".

## Architecture (only what the next session must hold in head)
- Key modules + responsibilities, by file path. Link the spec/plan rather than restating.

## Decisions (with rationale)
- <decision> — why; alternatives rejected. (These are what a cold session can't re-derive.)

## DONE (verified) — do not redo
- <item> — how verified (tests/▶/review).

## In progress / open threads
- <item> — exact state, next sub-step, any half-finished edits.

## NEXT (this handoff's goal)
- Scoped task list; explicit OUT-of-scope / deferred items + which milestone they belong to.

## Gotchas & gates
- Non-obvious traps; what needs user OK; what must stay reversible (backups, no force-push, etc.).

## File map
- The 3–8 paths that matter, one line each.
```

## Annotated kickoff example (generic web service)
Shows the principles in action — lean, reference-first, explicit DONE, concrete first action:

```
use superpowers. You're picking up the Orders API at the "idempotent retries" milestone. Read docs/specs/orders-api.md §4 and src/orders/handler.ts first; your MEMORY.md covers the project + conventions.

## What this is
A Node/Fastify service handling checkout orders; Postgres + a job queue.

## Where things live
Repo: ~/work/orders (branch `main`, git via `git -C ~/work/orders`). Spec: docs/specs/orders-api.md. Hot files: src/orders/handler.ts, src/orders/repo.ts, test/orders/*.test.ts.

## State (DONE — don't redo)
- Order create + validation shipped, 41/41 tests green, pushed to origin/main.
- Idempotency-key column + migration merged (see repo.ts:DECISIONS).

## Your task
Make POST /orders idempotent on retry (same key → same result, no double-charge). OUT of scope: webhook dedup (separate milestone).

## How to work
TDD via superpowers:test-driven-development; run `npm test` to verify. Conventions + commit rules: see CLAUDE.md.

## Gotchas
The queue publisher is at-least-once — dedup must be at the handler, not the worker.

## Gates
DB migrations need my OK before running against staging.

## Start by
Read handler.ts + the idempotency spec section, write a failing test for "same key returns the first result", then implement.
```

Why it works: ~200 words, zero pasted source, DONE list prevents rework, one unambiguous first action, defers out-of-scope work, leans on auto-loaded MEMORY.md/CLAUDE.md.

## Saving
Default: `docs/handoff/<YYYY-MM-DD>-<slug>.md` in the project. If the project keeps AI/process artifacts out of git (common), gitignore the handoff dir (or reuse an already-ignored docs path) — the files stay on disk for the next session, untracked.

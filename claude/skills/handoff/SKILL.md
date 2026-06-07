---
name: handoff
description: Use when handing the current session's work to a fresh Claude session — context is bloated or long, before /clear or compaction, when starting the next milestone or task in a new window, or when the user asks for a "handoff", "kickoff prompt", "continue this in a new session", or runs /handoff-prompt.
---

# Handoff

Produce a **fresh-session handoff**: an optimized, paste-ready **kickoff prompt** (always) plus an optional **state doc** for depth. The next session has ZERO conversation memory — but it DOES auto-load `CLAUDE.md` + `MEMORY.md`. The craft: give it everything needed to start correct work *by reference and a tight state summary*, never walls of pasted content.

## Core principle
**The kickoff prompt is a launch vector, not a knowledge dump.** Optimize for the fewest tokens that let a cold session begin correct work immediately. Point to files; don't inline them. Leverage what auto-loads; don't duplicate it.

## When to use
- Context window is large/bloated and you want a clean session.
- Before `/clear`, `/compact`, or opening a new window.
- Closing one milestone/task and teeing up the next.
- User says: "handoff", "kickoff prompt", "continue in a fresh session", or runs `/handoff-prompt`.

## Workflow
Copy this checklist and work it:
```
- [ ] 1. Snapshot state: git (branch, ahead/behind, last commits), what THIS session did, verified-vs-pending, open threads.
- [ ] 2. Pin the next goal (from the user's argument; else ask one line).
- [ ] 3. Inventory auto-loaded context (CLAUDE.md, MEMORY.md) — plan to REFERENCE, not duplicate.
- [ ] 4. Write the kickoff prompt (template below). Lean. Reference files by path.
- [ ] 5. If the work is complex, also write a fuller state doc (see templates.md) and link it from the prompt.
- [ ] 6. Save under docs/handoff/<YYYY-MM-DD>-<slug>.md; show the user the paste-ready prompt block.
- [ ] 7. Persist anything durable to MEMORY.md (decisions, gotchas) so the next session auto-loads it.
```

## What makes a prompt "optimized" (best-practice principles)
- **Leverage auto-load.** A fresh session reads `CLAUDE.md` + `MEMORY.md` automatically — write "your MEMORY.md covers X" instead of re-pasting. Biggest token win; also avoids staleness.
- **Reference, don't inline.** Give paths (spec, plan, key source files) the session reads on demand. Inlining large content burns the context you're saving.
- **Front-load.** Order: role + one-line goal → where things live → state (DONE vs NOT) → the task → how to work → first action.
- **Explicit DONE inventory.** List finished work so the session doesn't redo it — the highest-value section.
- **One concrete first action.** End with "Start by: <read X, then invoke Y>." A cold session needs an unambiguous first move.
- **Absolute dates.** "2026-05-31", never "today/yesterday".
- **Conventions by reference.** Which skills to use, the verify loop, gates — point to CLAUDE.md/memory; restate only the non-obvious, project-specific traps.
- **Name the gates.** What needs the user's OK; what must stay reversible.
- **Self-contained but lean.** Everything needed to act, nothing it can read for itself.

## Kickoff prompt template
Fill, then hand to the user as one paste-ready block:
```
[invoke ONLY the standing modes/skills this project actually uses — check its CLAUDE.md; e.g. "use superpowers and caveman". Don't list generic/irrelevant skills.] You're picking up <project> at <next goal>. Read <key files> first; your auto-loaded MEMORY.md covers the project + gotchas.

## What this is
<1–2 sentences.>

## Where things live
<repo path(s) + git rules; spec/plan/doc paths; the 2–4 source files that matter most.>

## State (DONE — don't redo)
<bullet the finished work + how it was verified; current branch, pushed?, test count.>

## Your task
<the next goal, scoped; what is explicitly OUT of scope / deferred to later.>

## How to work
<process skills to invoke; the verify loop; reference CLAUDE.md/MEMORY.md for conventions — don't duplicate.>

## Gotchas
<only the non-obvious, project-specific traps. Reference memory for the rest.>

## Gates
<what needs explicit user OK; what must be reversible.>

## Start by
<one concrete first action, then the next.>
```

Fuller state-doc template + an annotated real example: see [templates.md](templates.md).

## Common mistakes
- Pasting whole specs/plans/files into the prompt → bloats the new session. Link them.
- Duplicating CLAUDE.md/MEMORY.md → wasted tokens + drift. Reference it.
- Vague start ("continue the work") → cold session flails. Give the first action.
- Omitting the DONE list → the session redoes finished work.
- Relative dates → wrong next week. Absolute only.

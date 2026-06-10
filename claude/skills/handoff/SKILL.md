---
name: handoff
description: Use when handing the current session's work to a fresh Claude session — context is bloated or long, before /clear or compaction, when starting the next milestone or task in a new window, or when the user asks for a "handoff", "kickoff prompt", "continue this in a new session", or runs /handoff-prompt.
---

# Handoff

Produce a **fresh-session handoff**: an optimized, paste-ready **kickoff prompt** (always) plus an optional **state doc** for depth. The next session has ZERO conversation memory — but it auto-loads its **context** before reading your prompt. The craft: give it everything needed to start correct work *by reference and a tight state summary*, never walls of pasted content.

## Auto-loaded context (what the next session already has)
Before your prompt is read, a fresh session loads — and you must NOT re-state:
- **Global CLAUDE.md** (user's cross-project profile/conventions).
- **Project CLAUDE.md** (this repo's rules — architecture, gates, commit format, etc.).
- **Memory store, if the setup uses one** (e.g. MEMORY.md, an Obsidian vault/wiki) and **SessionStart-hook output** (e.g. a wiki catalog).

Build this inventory in step 3; everything in it is already known to the next session.

## Core principle
**The kickoff prompt is a launch vector, not a knowledge dump.** Fewest tokens that let a cold session begin correct work immediately. Point to files; don't inline them. Leverage what auto-loads; don't duplicate it.

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
- [ ] 3. Inventory auto-loaded context (see section above) — everything in it is REFERENCE-only, never re-stated.
- [ ] 4. Write the kickoff prompt (template below). Lean. Reference files by path.
- [ ] 5. If the work is complex, also write a fuller state doc (see templates.md) and link it from the prompt.
- [ ] 6. DEDUP PASS (before saving): re-read the draft line-by-line against the step-3 inventory. Delete any sentence the next session already knows. Every surviving convention mention must be a pointer or a binding (rule below) — never a restatement. Drop sections that auto-load fully covers.
- [ ] 7. Save under docs/handoff/<YYYY-MM-DD>-<slug>.md; show the user the paste-ready prompt block.
- [ ] 8. Persist anything durable (decisions, gotchas) to the project's memory setup (MEMORY.md, vault/wiki, …) so the next session auto-loads it.
```

## The no-duplication rule (the point of this skill)
A fresh session re-reads all auto-loaded context anyway, so restating it is pure token waste — and it goes stale when that context changes.

- **A pointer REPLACES the content.** Cite the section (`§7`, `CLAUDE.md §11`) instead of explaining it. Never cite *and* restate.
- **Bindings are the one allowed form of "restatement."** Connecting an auto-loaded rule to a concrete thing in THIS task is new information: "§7's owner-gate applies to `PlayerInteractor`" — keep. Re-explaining what §7 *says* — cut.
- **Omit fully-covered sections.** If auto-load covers `## How to work` or `## Gates`, delete the heading — don't fill it with pointers to everything.
- **Setup-agnostic:** applies to the project's local CLAUDE.md exactly as to the global one. If it auto-loads, don't duplicate it.

## What else makes a prompt "optimized"
- **Reference, don't inline.** Give paths (spec, plan, key source files) the session reads on demand. Inlining large content burns the context you're saving.
- **Front-load.** Order: role + one-line goal → where things live → state (DONE vs NOT) → the task → first action.
- **Explicit DONE inventory.** List finished work so the session doesn't redo it — the highest-value section, and the one thing auto-load can't supply.
- **One concrete first action.** End with "Start by: <read X, then invoke Y>." A cold session needs an unambiguous first move.
- **Absolute dates.** "2026-05-31", never "today/yesterday".
- **Deltas only.** Which skills *this project* uses, the task-specific verify loop, the gates needing user OK — as pointers + bindings, not re-explanations.

## Kickoff prompt template
Fill, then hand to the user as one paste-ready block. Omit any section that auto-loaded context fully covers.
```
[invoke ONLY the standing modes/skills this project actually uses — check its CLAUDE.md; e.g. "use superpowers and caveman". Don't list generic/irrelevant skills.] You're picking up <project> at <next goal>. Read <key files> first; your auto-loaded context covers the project + conventions.

## What this is
<1–2 sentences.>

## Where things live
<repo path(s); spec/plan/doc paths; the 2–4 source files that matter most. Git rules: pointer only, and only if non-obvious.>

## State (DONE — don't redo)
<bullet the finished work + how it was verified; current branch, pushed?, test count.>

## Your task
<the next goal, scoped; what is explicitly OUT of scope / deferred to later.>

## How to work        ← omit if auto-load covers it; else deltas only
<task-specific verify loop or process; reference conventions by section, don't restate.>

## Gotchas
<only the non-obvious, project-specific traps, as bindings. The cold session already has the general rules.>

## Gates                ← omit if auto-load covers it; else deltas only
<what needs explicit user OK for THIS task; what must stay reversible.>

## Start by
<one concrete first action, then the next.>
```

Fuller state-doc template + an annotated real example: see [templates.md](templates.md).

## Common mistakes
- **Cite-and-restate** — naming `§7` then re-explaining it. The citation is enough; the restatement is the waste this skill exists to kill.
- **Pasting whole specs/plans/files** into the prompt → bloats the new session. Link them.
- **Re-stating project CLAUDE.md / memory** → wasted tokens + drift. The fresh session already loaded them. Reference by section.
- **Narrating the load mechanism** ("the SessionStart hook will load X", "your MEMORY.md auto-loads Y") → the session sees that itself; just use the knowledge.
- **Vague start** ("continue the work") → cold session flails. Give the first action.
- **Omitting the DONE list** → the session redoes finished work.
- **Relative dates** → wrong next week. Absolute only.

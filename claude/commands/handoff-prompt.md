---
description: Generate an optimized fresh-session handoff (kickoff prompt + optional state doc) for the next milestone/task
argument-hint: [next milestone or task, e.g. "M4 feature-slice"]
---

Use the `handoff` skill to produce a fresh-session handoff for the current project.

Next-session target: $ARGUMENTS

Follow the handoff skill's workflow exactly: snapshot current state (git branch/ahead-behind/last commits + what this session accomplished, verified vs pending), pin the next goal, then write a lean, paste-ready **kickoff prompt** — referencing files by path and leaning on the next session's auto-loaded context (global + project CLAUDE.md, memory store, SessionStart-hook output) rather than duplicating it. Run the skill's dedup pass before saving. Add a fuller state doc only if the work is complex. Save under `docs/handoff/<YYYY-MM-DD>-<slug>.md`, persist any durable decisions/gotchas to the project's memory setup, and show me the paste-ready prompt block.

If no target was given, ask one line: "What's the next session working on?" before generating.

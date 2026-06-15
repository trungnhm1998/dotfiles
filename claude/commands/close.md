---
description: Close the session — capture durable knowledge to 05.Wiki and refresh continuity, then mark the ledger captured
argument-hint: [optional focus, e.g. "the URP batching gotcha"]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
model: inherit
---

Run the **close-session protocol** (the `close-session` skill). Optional focus from the user: $ARGUMENTS
(If empty, scan the whole session for what's worth keeping; if present, prioritise it.)

Execute both channels — durable knowledge → `05.Wiki/` (git-committed), continuity →
`<cwd>/.planning/continuity.md` — then run `bash ~/.claude/hooks/ledger-mark-captured.sh "$PWD"`
and report what you wrote. Follow the `close-session` skill exactly.

---
description: Review the current Unity C# diff for performance and lifecycle bugs
argument-hint: [optional path filter]
allowed-tools: Read, Grep, Glob, Bash(git diff:*), Bash(git status:*)
model: inherit
---

Changed C# files:
!`git diff --name-only -- '*.cs' 2>/dev/null; git status --porcelain -- '*.cs' 2>/dev/null`

Dispatch the **unity-code-reviewer** subagent to review the changed C# shown above. Optional path filter from the user: $ARGUMENTS

If no changed C# is detected, ask the user which file or path to review instead. Return the reviewer's findings plus a clear go / no-go for committing.

---
description: Run a code review on specified files
allowed-tools: Read, Grep, Glob
model: claude-3-5-haiku-20241022
---

Delegate to the code-reviewer subagent.

Review these files/changes: $ARGUMENTS

Use the full review checklist. Output in severity format (🔴🟡🟢✅).
After the review, suggest which issues to fix first based on impact.


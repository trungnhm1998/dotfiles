---
name: mentor
description: Token-usage coaching report. Trigger on /mentor, "mentor report", "how is my token usage".
---

# Mentor

Deep review of Max's Claude Code token habits. The `mentor.py` PostToolUse hook
already flagged waste live and for free; this skill only reads its digest.

## Steps

1. Read `~/.claude/mentor.log` (JSONL: `t`, `sid`, `rule`, `advice`, `waste`).
   Missing or empty = no waste detected yet; say so and stop.
2. Aggregate by `rule`: count, total `waste` tokens, first/last date.
3. Report, at most 10 lines:
   - Top 3 habits by wasted tokens, each with the one concrete substitution.
   - Trend: is the rule firing less over the last 7 days than the 7 before?
     Improving habits are the point; say which ones improved.
   - One thing to practise next session. One only.
4. If every rule has stopped firing for 7+ days, say the hook has done its job
   and offer the kill switch: `touch ~/.claude/mentor-off`.

## Rules

- Do not re-derive the analysis from transcripts. The log is the digest; reading
  raw `.jsonl` transcripts to write a token report is self-defeating.
- No praise padding. Numbers, substitution, next action.

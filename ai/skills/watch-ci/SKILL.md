---
name: watch-ci
description: Use when a pushed branch or PR has CI running and it should be driven to green without the user babysitting it — "watch CI", "babysit the build", after pushing a fix, or when a pipeline is red and needs diagnose-fix-repush iteration.
---

# Watch CI — self-healing loop until green

Drive a branch/PR's CI to green autonomously: watch → on red, diagnose → fix → re-push → repeat. Stop only on green, a hard cap, or a genuinely-human step.

## The loop

1. **Identify the target**: current branch's PR (`gh pr view --json number,headRefName,url`). No PR? Watch the branch's latest workflow run instead (`gh run list --branch <branch> --limit 1`).
2. **Watch cheaply** with the Monitor tool:
   - Poll `gh pr checks <n>` (or the run status) every 90 s; 150 s+ for known-long pipelines (Unity builds).
   - **stdout = terminal events only** (`GREEN` / `RED:<job>` / `TIMEOUT`); heartbeats and progress go to **stderr**. Every stdout line becomes a user-facing notification.
   - Cover **every** terminal state — success, failure, cancelled, timeout. Silence must never mean success.
3. **On red**: `gh run view <id> --log-failed` for the full failing-job log. Diagnose root cause first — REQUIRED: superpowers:systematic-debugging. No speculative patches.
4. **Fix → verify locally** (run the failing test/lint locally; if the failure is infra/platform-only and can't reproduce locally, say so in the iteration report and let CI be the test) → commit → push (SSH remote; if the remote is HTTPS on a private repo, switch it to SSH first) → back to 2.
5. **Report**: one line per iteration (what failed, what changed); on green, a short summary of every fix applied.

## Stop conditions (hard)

- ✅ CI green → report and stop.
- ❌ **3 consecutive failed fix attempts** on the same failure, or **6 fix iterations total** across all failures → stop, summarize evidence + remaining hypotheses, hand back.
- 🧍 The failure needs a human-only step (Unity Editor action, secrets/permissions, infra) → stop and state exactly what's needed.

## Invariants

- The invocation is the approval to push fixes **to the same branch only**. Never force-push, never rebase, never touch other branches.
- After any compaction/resume, **re-verify live CI state** (`gh pr checks`) before acting — never trust a pre-compaction watcher verdict.
- Re-invocation must converge: audit what's already pushed/fixed and do only what's missing.

## Common mistakes

- Per-minute heartbeats on stdout → notification spam (one real watch produced ~50 of them). Heartbeats → stderr.
- Grepping only for the success marker → a crashloop looks like "still running". Match failure states too.
- Fixing the symptom visible in the log tail instead of opening the full failing-job log.

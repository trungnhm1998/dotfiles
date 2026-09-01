---
description: Verify that a Unity/C#/package API or method signature is real and current
argument-hint: [API, method, or snippet to verify]
allowed-tools: Read, Grep, Glob, WebSearch, WebFetch
model: inherit
---

Verify this API, method signature, or claimed behavior: $ARGUMENTS

Dispatch the **docs-verifier** subagent to check it against authoritative sources (context7 + Unity Scripting Reference + package docs) for Unity 6.x / URP unless the user specifies a different version.

Return the verifier's verdict in this format:
**Verdict:** Confirmed ✅ / Wrong ❌ / Changed-or-version-specific ⚠️
**Evidence:** [exact source detail / correct signature]
**Correct usage:** [the right form, if wrong or changed]
**Source:** [URL or context7 library id]

If $ARGUMENTS is empty, ask the user what API or behavior they want to verify.

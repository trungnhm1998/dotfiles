---
description: Plan-then-implement workflow for a feature
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

Follow this strict workflow for: $ARGUMENTS

PHASE 1 — PLAN (stay in plan mode thinking):
1. Analyze the existing codebase for related systems
2. Propose architecture with interfaces and class structure
3. Identify what needs testing (TDD entry points)
4. Present the plan and WAIT for my approval

PHASE 2 — TEST (only after I approve):
5. Write failing tests first (Red phase)
6. Show me the tests and WAIT for confirmation

PHASE 3 — IMPLEMENT (only after test approval):
7. Write minimum code to pass tests (Green phase)
8. Run tests to verify

PHASE 4 — REFACTOR:
9. Apply SOLID principles, extract methods, clean up
10. Run full test suite
11. Delegate to code-reviewer subagent for final review


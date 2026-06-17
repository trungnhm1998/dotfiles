# Max — Solo Unity Indie Dev

I'm a solo developer going full-time indie. Main stack: **Unity 6.x LTS + URP**, C#, both 2D & 3D. I'm intermediate and leveling up — explain the *why* so I learn, don't just hand me answers.

## How to answer me
- Give 2–3 options with honest trade-offs, then a clear recommendation. Be decisive, but show the reasoning.
- Teach the underlying principle briefly when it helps me grow.
- Before non-trivial exploration, state a 2-line plan of what you'll read and why, then produce a first draft I can refine — don't exhaustively gather context before showing anything.
- Cite `file:line` for code; cite a source for factual/API claims.
- For diagrams, use **Mermaid** syntax — never ASCII art. **Validate every diagram by rendering it before sending** — use the `beautiful-mermaid` skill (`node ~/.claude/skills/beautiful-mermaid/scripts/mermaid.mjs`) or another renderer; never post an un-rendered Mermaid block. (Common breakers: class-diagram members must be newline-separated and avoid `[]` array types; keep node labels simple.)

## Engineering defaults (Unity / C#)
- Default new projects to Unity 6.x LTS + URP unless told otherwise.
- The full Unity/C# engineering + testing conventions live in the path-scoped rule `~/.claude/rules/unity-csharp.md` — it loads automatically whenever `.cs` files are in play, so don't restate them here.

## Verify, don't guess
- Confirm Unity/package APIs against **context7** + official docs before asserting them.
- When a Unity project is open, use the **Unity MCP** bridge to check the Editor / console / play mode rather than guessing.

## Indie guardrails
- Default to **scope discipline**: challenge feature creep, prefer the smallest vertical slice that proves the fun, and ask "does this serve the game I'm shipping?"
- Buy-vs-build is case-by-case. I lean toward building things myself — respect that, but flag clearly when buying wins on time or quality.

## Don't reinvent
- Use my existing tools: superpowers (brainstorming, TDD, systematic-debugging, writing-plans, code-review) and context7. Build on them.

## Memory — my Obsidian vault IS the memory store
My durable, cross-project memory lives in my Obsidian vault, where you **must read and update** during our session — its path on the current machine is injected at session start by the `vault-map` hook (and available as `$OBSIDIAN_VAULT`; e.g. `~/obsidian-vault/main` on macOS, `C:\ObsidianVaults` on Windows). It holds PARA notes (my hand-curated, in my voice) + the **agent-owned LLM-Wiki at `05.Wiki/`** (governed by the vault's `CLAUDE.md` and `05.Wiki/CLAUDE.md`). **Do NOT use Claude Code's file-based auto-memory** (`~/.claude/projects/*/memory/`) — it's been retired and wiped. The vault is the single source of truth for what I know, prefer, and have decided. This applies in **every** project, whatever the working directory.

- **Recall:** when a question is about *my* knowledge, preferences, past decisions, or cross-project learnings ("what do I know about X", "did I note Y", "how did I solve Z before"), read the vault — start at `_Home` or `05.Wiki/index.md`, then follow `[[links]]`. Don't detour into the vault for ordinary in-repo coding; reach for it when the question is about my own knowledge.
- **Persist (instead of auto-memory):** whenever a session produces durable knowledge worth keeping — a learned convention, a hard-won gotcha, a project fact, my feedback — write it into the vault, not to auto-memory:
  - Agent-compiled reference / lessons / project facts → **`05.Wiki/`** (you own it; follow the LLM-Wiki ingest rules in `05.Wiki/CLAUDE.md` — update existing pages don't duplicate, link liberally, refresh `index.md`, append `log.md`).
  - Notes in *my* voice → PARA, **Inbox-first** per the vault's `CLAUDE.md`.
- **Ingest on request:** when I drop a source into `05.Wiki/raw/` or share something in chat and ask you to capture/ingest it, follow the `05.Wiki/CLAUDE.md` ingest flow (read → discuss → write → link → log).
- **Editing vault files:** re-read a vault file immediately before editing it — Obsidian often holds files open and changes them on disk, and stale edits get rejected.
- If you can't write to the vault from the current project (directory-access prompt), say so and ask me to grant it (add the vault path to `~/.claude/settings.local.json` under `permissions.additionalDirectories`) — don't silently fall back to auto-memory.

## Git
- Never add `Co-Authored-By` trailers or AI-attribution footers (e.g. "Generated with Claude Code") to commits.
- When pushing to private repos, always use SSH remotes (git@...) rather than HTTPS.

## Safety
- Ask before destructive actions: deleting scenes/assets/prefabs, large refactors, or rewriting git history.

## Code Intelligence

Prefer LSP over Grep/Read for code navigation — it's faster, precise, and avoids reading entire files:
- `workspaceSymbol` to find where something is defined
- `findReferences` to see all usages across the codebase
- `goToDefinition` / `goToImplementation` to jump to source
- `hover` for type info without reading the file

Use Grep only when LSP isn't available or for text/pattern searches (comments, strings, config).

After writing or editing code, check LSP diagnostics and fix errors before proceeding.

## Bug Fix Workflow
- After fixing a bug and opening a PR, capture the root cause and resolution into the Obsidian wiki vault, then move the related Jira ticket to Tech Review.

## Windows / Shells
- Prefer the PowerShell tool directly for Windows commands instead of routing PowerShell through Bash, since Bash mangles the escaping. Use full absolute paths to avoid persisted-cd / exit-127 issues.

## Communication Style
- When explaining design options or architecture, lead with concrete code examples rather than abstract descriptions.

## Debugging
- Verify log channel reliability before using one (avoid print/LogService:LogInfo unless confirmed); confirm with editor logs when diagnosing races.

## Compact instructions
When compacting, always preserve: the list of files modified this session, test/build commands and their latest results, the active ticket/branch/PR, and any unresolved blockers or pending approvals.


# Max — Solo Unity Indie Dev

I'm a solo developer going full-time indie. Main stack: **Unity 6.x LTS + URP**, C#, both 2D & 3D. I'm intermediate and leveling up — explain the *why* so I learn, don't just hand me answers.

## How to answer me
- Give 2–3 options with honest trade-offs, then a clear recommendation. Be decisive, but show the reasoning.
- Teach the underlying principle briefly when it helps me grow.
- Cite `file:line` for code; cite a source for factual/API claims.
- For diagrams, use **Mermaid** syntax — never ASCII art.

## Engineering defaults (Unity / C#)
- Prefer composition and plain C# services + ScriptableObjects over deep MonoBehaviour inheritance.
- Be performance-aware: flag per-frame heap allocations (LINQ/boxing/`string` concat/`Camera.main`/`GetComponent` in `Update`) and frame-budget costs.
- Use assembly definitions; namespaces mirror folders; one type per file.
- Default new projects to Unity 6.x LTS + URP unless told otherwise.
- Avoid deprecated Unity APIs (`OnGUI`, `WWW`, legacy `Input` manager) — prefer UI Toolkit / `UnityWebRequest` / the new Input System.

## Testing
- Name unit tests **`UnitUnderTest_StateUnderTest_Expected`** (e.g. `Aggregate_WithNoModifiers_ReturnsBase`) — the method/type under test, the scenario, then the expected outcome; PascalCase segments joined by `_`.

## Verify, don't guess
- Confirm Unity/package APIs against **context7** + official docs before asserting them.
- When a Unity project is open, use the **Unity MCP** bridge to check the Editor / console / play mode rather than guessing.

## Indie guardrails
- Default to **scope discipline**: challenge feature creep, prefer the smallest vertical slice that proves the fun, and ask "does this serve the game I'm shipping?"
- Buy-vs-build is case-by-case. I lean toward building things myself — respect that, but flag clearly when buying wins on time or quality.

## Don't reinvent
- Use my existing tools: superpowers (brainstorming, TDD, systematic-debugging, writing-plans, code-review) and context7. Build on them.

## Memory — my Obsidian vault IS the memory store
My durable, cross-project memory lives in the Obsidian vault at `C:\ObsidianVaults` — PARA notes (my hand-curated, in my voice) + the **agent-owned LLM-Wiki at `05.Wiki/`** (governed by `C:\ObsidianVaults\CLAUDE.md` and `05.Wiki\CLAUDE.md`). **Do NOT use Claude Code's file-based auto-memory** (`~/.claude/projects/*/memory/`) — it's been retired and wiped. The vault is the single source of truth for what I know, prefer, and have decided. This applies in **every** project, whatever the working directory.

- **Recall:** when a question is about *my* knowledge, preferences, past decisions, or cross-project learnings ("what do I know about X", "did I note Y", "how did I solve Z before"), read the vault — start at `_Home` or `05.Wiki/index.md`, then follow `[[links]]`. Don't detour into the vault for ordinary in-repo coding; reach for it when the question is about my own knowledge.
- **Persist (instead of auto-memory):** whenever a session produces durable knowledge worth keeping — a learned convention, a hard-won gotcha, a project fact, my feedback — write it into the vault, not to auto-memory:
  - Agent-compiled reference / lessons / project facts → **`05.Wiki/`** (you own it; follow the LLM-Wiki ingest rules in `05.Wiki\CLAUDE.md` — update existing pages don't duplicate, link liberally, refresh `index.md`, append `log.md`).
  - Notes in *my* voice → PARA, **Inbox-first** per the vault's `CLAUDE.md`.
- **Ingest on request:** when I drop a source into `05.Wiki/raw/` or share something in chat and ask you to capture/ingest it, follow the `05.Wiki\CLAUDE.md` ingest flow (read → discuss → write → link → log).
- If you can't write to `C:\ObsidianVaults` from the current project (directory-access prompt), say so and ask me to grant it — don't silently fall back to auto-memory.

## Git
- Never add `Co-Authored-By` trailers or AI-attribution footers (e.g. "Generated with Claude Code") to commits.

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
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

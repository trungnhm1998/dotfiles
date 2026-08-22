I'm Max, a game developer. Main stack: **Unity 6.x LTS + URP**, C#, both 2D & 3D. I'm intermediate and leveling up.

## Must do
- Use obsidian vault wiki for knowledge, query using graphify
- Code should comment it self, following clean code principles, and be readable by humans. Avoid over-commenting obvious things.
- Only comment code if really necessary for examples regex meaning.
- Favor composition over inheritance, and prefer interfaces over abstract classes.

## Must not
- commit specs/plans file by superpower skills

## Working principles
- **Surface, don't assume.** If multiple interpretations exist, name them and recommend one — never pick silently. If a simpler approach exists, say so; push back when warranted. Ask only when the choice is destructive or genuinely mine to make; otherwise default and note the assumption.
- **Surgical changes.** Every changed line traces to my request — don't "improve" adjacent code, match existing style, remove only the orphans your own change created.
- **Verifiable goals — red, green, refactor.** Turn tasks into checks you can run. Bug fix: reproduce the **red first** and prove it actually ran — a failing test, or a manual/agent-driven repro whose logs show the buggy path executed. An unverified repro is a false green: it "passes" because the code path was never reached, not because the bug is gone. Only then the **minimal** change to green, then refactor. For multi-step work, state a brief step → verify plan, then loop until the checks pass.

## How to answer me
- Be concise
- Design/architecture choices: 2–3 options with honest trade-offs, then a clear recommendation. Implementation details: just decide and say why.
- Teach the underlying principle briefly when it helps me grow; lead with concrete code examples over abstract description.
- Before non-trivial exploration, state a 2-line plan of what you'll read and why, then show a first draft I can refine.
- Cite `file:line` for code; cite a source for factual/API claims.
- Diagrams: **Mermaid only**, validated with the `beautiful-mermaid` skill (`--check`) before posting. Never post an un-rendered Mermaid block.
- Only in plain ascii text that I can type, do not use em dashes, smart quotes, or other Unicode punctuation.

## Unity / C#
- Default new projects to Unity 6.x LTS + URP unless told otherwise.
- Full engineering + testing conventions live in the path-scoped rule `~/.claude/rules/unity-csharp.md` — auto-loads with `.cs` files; don't restate.
- **Verify, don't guess:** confirm Unity/package APIs against context7 + official docs; with a project open, use the Unity MCP bridge to check the Editor/console/play mode rather than guessing.
- Verify a log channel actually works before trusting it; confirm with editor logs when diagnosing races.

## Memory — my Obsidian vault IS the memory store
My durable, cross-project memory is my Obsidian vault — read and update it during our sessions, in **every** project. Its path is injected at session start by the `vault-map` hook (also `$OBSIDIAN_VAULT`). It holds my hand-curated PARA notes plus the **agent-owned LLM-Wiki at `05.Wiki/`** (governed by the vault's `CLAUDE.md` and `05.Wiki/CLAUDE.md`). **Do NOT use file-based auto-memory** (`~/.claude/projects/*/memory/`) — retired and wiped; the vault is the single source of truth.

- **Recall:** for questions about *my* knowledge, preferences, or past decisions ("what do I know about X", "how did I solve Z before"), read the vault — start at `_Home` or `05.Wiki/index.md`, follow `[[links]]`. Don't detour into it for ordinary in-repo coding. Always try to use Graphify to query from vault for faster and less tokens.
- **Persist:** durable knowledge from a session goes to the vault — agent-compiled reference/lessons/facts → `05.Wiki/` (follow its ingest rules in `05.Wiki/CLAUDE.md`); notes in *my* voice → PARA, Inbox-first.
- Re-read a vault file immediately before editing it — Obsidian holds files open; stale edits get rejected.
- If you can't write to the vault from the current project, say so and ask me to grant access (`permissions.additionalDirectories`) — never silently fall back to auto-memory.

## Git
- **Never** add `Co-Authored-By` trailers or AI-attribution footers to commits. (Claude Code: also enforced via `includeCoAuthoredBy: false` in settings.)
- Private repos: SSH remotes (`git@…`), never HTTPS.

## Safety
- Ask before destructive actions: deleting scenes/assets/prefabs/folders/files, large refactors, rewriting git history.
- Do not use `AskUserQuestion` tool, instead ask in plain text.

## Long-running commands
- Before any script/bench/build/CI run: state an expected duration and set the tool timeout to that ETA plus margin. Past the ETA: stop waiting — investigate, fix, retry. (A silent 30-min hang once burned a whole session.)
---

## Claude Code specific
- Prefer LSP over Grep/Read for code navigation; after writing or editing code, check LSP diagnostics and fix errors before proceeding.
- Use my existing skills first — superpowers (brainstorming, TDD, systematic-debugging, writing-plans, code-review) and context7 — don't rebuild what they cover.
- When compacting, always preserve: files modified this session, test/build commands and their latest results, the active ticket/branch/PR, and unresolved blockers or pending approvals.


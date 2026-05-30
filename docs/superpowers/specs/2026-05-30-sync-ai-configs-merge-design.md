# Spec: Safe union-merge of AI configs (Claude Code + opencode)

**Date:** 2026-05-30
**Branch:** `feat/sync-ai-tool-configs`
**Status:** Approved design, pending implementation plan

## Problem

`deploy_windows.ps1` symlinks Claude Code and opencode configs from the dotfiles
repo over the live Windows configs. The live configs have diverged substantially
from the (older/aspirational) dotfiles versions, and several live targets are
**not** symlinks — they are real files/dirs and, in the case of `~/.claude/skills`,
**plugin-managed junctions**. Running the script as-is would:

- Replace the rich live `opencode.jsonc` (providers, models, API key) with a 20-line stub → opencode breaks.
- Whole-dir-symlink `~/.claude/skills`, **destroying plugin junctions** (caveman, find-skills, skill-creator, …).
- Replace divergent `agents/`/`commands/` sets (near-zero name overlap) → lose live items.
- Overwrite `settings.json`, losing the Windows-only proxy (`ANTHROPIC_BASE_URL=http://localhost:8080`) and notify hook.
- Risk **committing a secret** (`opencode.jsonc` has a hardcoded `sk-…` API key).

## Goal

Sync AI configs as a **union merge**: combine skills/commands/agents/configs where
they don't collide; where a merge isn't clean, **live wins**. Never clobber plugin
junctions, machine-specific settings, or secrets; never commit secrets.

## Decisions (locked)

| Topic | Decision |
|-------|----------|
| Directory-merge approach | **B — Hybrid**: whole-dir symlink for agents+commands (union'd into repo first); per-item symlinks for skills (preserve junctions) |
| Collisions (`unity-code-reviewer`, `learn`) | **Live wins** (not cleanly mergeable) |
| Agent frontmatter | Add a `color:` field to any agent `.md` missing one |
| `settings.json` machine-specific bits | **Strategy 1 — Symlink + externalize.** Proxy → Windows-only OS env var; notify hook → cross-platform `hooks/` script |
| `opencode.jsonc` | **Live wins**, sanitized (externalize `sk-…` key; consolidate duplicate `agent` key) |
| `CLAUDE.md` | Keep the **minimal indie-dev** version as canonical; optionally graft one deprecated-API guardrail line |
| `statusline*` | Keep existing dotfiles symlinks (live runs `ccstatusline`; these are inert) |

## Verified facts (Claude Code settings)

- **There is no user-level `~/.claude/settings.local.json`.** `settings.local.json`
  is project-scoped only. The only user-global settings file is `~/.claude/settings.json`.
  Source: https://code.claude.com/docs/en/settings
- Precedence (high→low): Managed > CLI > Local (project) > Project > User.
- Because the synced `settings.json` is identical on every machine, a Windows-only
  proxy cannot live in it safely → it goes in a per-machine OS env var instead.

## Design

### 1. Claude `agents/` + `commands/` — union, then whole-dir symlink

Consolidate the union **into the repo and commit** before any symlink runs:

- **agents/** → 10 total: dotfiles-only (`docs-verifier`, `gamedev-researcher`,
  `unity-architect`) + live (`engine-docs-researcher`, `game-debugger`,
  `game-design-critic`, `gameplay-test-writer`, `perf-optimizer`,
  `shader-graphics-specialist`, `unity-code-reviewer`). Collision
  `unity-code-reviewer` → **live** copy wins.
- **commands/** → 8 total: dotfiles-only (`new-game`, `scope-check`,
  `unity-review`, `verify-api`) + live (`design`, `implement`, `learn`, `review`).
  Collision `learn` → **live** copy wins.
- Add `color:` frontmatter to any agent missing it.
- The existing whole-dir symlinks (`~/.claude/agents` → repo, `~/.claude/commands`
  → repo) then resolve correctly. Back up live dirs first.

### 2. Claude `skills/` — per-item symlinks (critical change)

Replace the script's **whole-dir** skills symlink with a **per-item loop**:
for each `claude/skills/<name>` in the repo, create `~/.claude/skills/<name>` as a
symlink **only if a target of that name does not already exist**. The 8 gamedev
skills (`game-feel`, `game-marketing`, `gamedev-art`, `gamedev-audio`,
`indie-production`, `level-design`, `unity-engineering`, `unity-shaders`) link in;
all live junctions stay untouched. Names don't overlap → zero collisions. Live
community skill dirs (`beautiful-mermaid`, `explain-code`, `unity-mcp-skill`) are
left as-is (not pulled into the repo).

### 3. `settings.json` — Strategy 1 (symlink + externalize)

- **Synced `claude/settings.json`** (symlinked to `~/.claude/settings.json`): merged
  **portable** keys only — from live (`statusLine`, `enabledPlugins`, `effortLevel`,
  `theme`, `editorMode`, `verbose`, `agentPushNotifEnabled`, `autoUpdatesChannel`,
  `awaySummaryEnabled`, `skipAutoPermissionPrompt`, `permissions`) **plus** dotfiles'
  `SessionStart` unity-detect hook. **No `env`/proxy block.** Notify hook points at
  the cross-platform script (below).
  - Plugin/marketplace reconciliation (default): keep live's
    `superpowers@claude-plugins-official`; drop the dotfiles
    `obra/superpowers-marketplace` `extraKnownMarketplaces` entry to avoid a dual
    source. *(Flag if standardizing on the marketplace instead.)*
- **Proxy** `ANTHROPIC_BASE_URL=http://localhost:8080` → set as a **Windows user OS
  env var** by `deploy_windows.ps1` (alongside `XDG_CONFIG_HOME` etc.). Mac deploy
  does not set it → no proxy on Mac.
- **Notify hook** → new `claude/hooks/claude-notify.sh` (bash, cross-platform):
  reads stdin JSON, extracts `.message`, and on Windows invokes the existing
  `C:\Tools\claude-notify.ps1 -Message … -PaneId $WEZTERM_PANE`; no-ops (or uses a
  native notifier) elsewhere. The synced `settings.json` `Notification` hook calls
  `bash ~/.claude/hooks/claude-notify.sh`.

### 4. `opencode.jsonc` — live wins, sanitized

Replace the repo stub with the live config, with two pre-commit fixes:

- **Externalize the secret**: line ~195 `apiKey: "sk-e13b…"` → `"{env:NINEROUTER_API_KEY}"`.
  Add `NINEROUTER_API_KEY` to `secrets.env.example` (placeholder) and the real value
  to `~/.config/dotfiles/secrets.env` (gitignored). The Windows deploy already loads
  `secrets.env` into user env vars.
- **Consolidate the duplicate `"agent"` key** (top `title`/`build`/`plan` block +
  bottom `explorer` block) into one valid block.
- Keep live providers, models, plugins, and ports (`unitymcp :8081`). Symlink as the
  script already does. Keep the script's removal of stale `opencode.json`.

### 5. `CLAUDE.md` + statusline

- `claude/CLAUDE.md`: keep the minimal indie-dev version; optionally add one line:
  *"Avoid deprecated Unity APIs (OnGUI, WWW, legacy Input)."* Back up the live 5.5KB version.
- `statusline.sh` / `statusline-command.sh`: keep existing dotfiles symlinks (inert
  under `ccstatusline`). Back up live `statusline.sh`.

### 6. `deploy_windows.ps1` changes

1. **Skills**: change the `claude\skills` entry from a whole-dir symlink to a
   per-item symlink loop (skip-if-exists), preserving existing junctions.
2. **Proxy env var**: add `ANTHROPIC_BASE_URL = http://localhost:8080` to the
   `$envVars` block (Windows-only).
3. **Notify hook script**: ship `claude/hooks/claude-notify.sh`; ensure
   `claude/hooks` is symlinked (already in `$symlinks`).
4. **Secrets**: add `NINEROUTER_API_KEY` to the secrets bootstrap / example.
5. Agents, commands, opencode, settings.json, CLAUDE.md symlinks stay as-is (now
   backed by union'd/sanitized content).

## Rollout

1. Consolidate union content + sanitize secrets **in the repo**, commit.
2. `deploy_windows.ps1 -DryRun` → review planned actions.
3. Run for real **with backups enabled** (targets moved to `*.backup_<timestamp>`).
4. Verify: `claude` starts (proxy via env var), opencode loads providers, plugin
   skills still present, gamedev skills linked, agents/commands union present.

## Net effect

Union of all agents/commands/skills; live wins on every genuine conflict;
machine-specific bits (proxy, notify hook) and secrets (API keys) stay local and
gitignored; no plugin junction or API key is ever clobbered or committed.

## Open (non-blocking) flags

- §3 plugin/marketplace source: default keeps live's `claude-plugins-official`.
- §5 deprecated-API line in `CLAUDE.md`: include? (default: yes, cheap + high-value).

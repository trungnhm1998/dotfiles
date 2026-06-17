# Design: Single canonical global agent-instructions file (AGENTS.md)

- **Date:** 2026-06-09
- **Status:** Approved (design) — pending spec review
- **Repo:** `dotfiles` (`git@github.com:trungnhm1998/dotfiles.git`), branch `master`
- **Author:** Max + Claude (brainstorming)

## Goal

Make Max's **global, user-level** agent instructions (currently `claude/CLAUDE.md`, the
"Max — Solo Unity Indie Dev" guidance) live in a single canonical `AGENTS.md` so that
Claude Code, Codex, opencode, and Cursor all read the *same* instructions — edit one file,
every agent picks it up.

> Scope note: this is about the **global user instructions** that deploy to `~/.claude/`.
> It is **not** the repo-root `CLAUDE.md` / `AGENTS.md`, which describe how to work *on* the
> dotfiles repo and are out of scope.

## Key facts (verified, not assumed)

Each agent reads its **global** instructions from a different path:

| Tool | Global location | Notes |
|------|-----------------|-------|
| Claude Code | `~/.claude/CLAUDE.md` | filename must be `CLAUDE.md`; symlink target name is irrelevant |
| Codex | `~/.codex/AGENTS.md` (or `$CODEX_HOME/AGENTS.md`) | global-file reading has had bugs — needs a recent Codex ([#8759](https://github.com/openai/codex/issues/8759)) |
| opencode | `~/.config/opencode/AGENTS.md` | takes precedence over its fallback to `~/.claude/CLAUDE.md` |
| Cursor | **none** | User Rules live in Cursor's synced settings DB; `~/.cursor/rules` is known-broken; `AGENTS.md` is read only at a **project** root |

Sources: [Codex AGENTS.md](https://developers.openai.com/codex/guides/agents-md) ·
[opencode Rules](https://opencode.ai/docs/rules/) · [Cursor Rules](https://cursor.com/docs/rules).

Repo facts that shape the design:
- Canonical content today: `dotfiles/claude/CLAUDE.md` (~5.3 KB), a plain file.
- `deploy_windows.ps1` builds a `$symlinks` array; the Claude `CLAUDE.md` entry is at
  ~L143–146, opencode at ~L188–193. It creates **real** symlinks (Developer Mode is on).
- macOS/Linux delegate to one shared script: `scripts/sync-ai-configs.sh`
  (idempotent `link_config <src> <target>`; the Claude loop is at L28–30, opencode at L34).
- The repo's local `core.symlinks=false` → committing an in-repo symlink would check out as a
  **text file** on Windows. This is why we avoid in-repo symlinks (see Approach).

## Approach (chosen): Option 3 — deploy-script fan-out

One canonical file in the repo; the deploy scripts point every tool's real global path at it.
This matches the repo's existing "canonical file → deploy fans out home-dir symlinks" paradigm,
has **zero** in-repo symlink fragility, and still yields a real `CLAUDE.md → AGENTS.md` symlink —
in `~/.claude`, where it functionally matters.

Rejected alternatives:
- **Option 1 (in-repo symlink `claude/CLAUDE.md` → `AGENTS.md`):** literal request, but
  `core.symlinks=false` breaks it on fresh Windows clones.
- **Option 2 (`@AGENTS.md` import in `claude/CLAUDE.md`):** robust, matches the repo *root*
  convention, but adds a second repo file and depends on Claude-only import resolution through
  the `~/.claude` symlink. Unnecessary once Option 3 points `~/.claude/CLAUDE.md` straight at the file.

## Repo layout after change

```
dotfiles/claude/
├── AGENTS.md      ← canonical content (moved verbatim from CLAUDE.md)
├── settings.json
├── statusline.sh  statusline-command.sh
├── agents/  commands/  hooks/  skills/
   (claude/CLAUDE.md is removed — nothing in the repo reads it directly anymore)
```

**Content:** moved **verbatim**. It *is* "the same instruction." Claude-only references
(superpowers/skills, the auto-memory ban, Unity MCP, context7) are harmless to other agents —
they ignore unknown skill names. No genericization in this change.

## Home-dir link topology (created by deploy scripts)

All four symlinks point at the single canonical file `dotfiles/claude/AGENTS.md`:

| Symlink (home) | → Target | For |
|----------------|----------|-----|
| `~/.claude/CLAUDE.md` | `…/dotfiles/claude/AGENTS.md` | Claude Code (primary) |
| `~/.claude/AGENTS.md` | `…/dotfiles/claude/AGENTS.md` | safety-net / future Claude AGENTS support |
| `~/.codex/AGENTS.md` | `…/dotfiles/claude/AGENTS.md` | Codex |
| `~/.config/opencode/AGENTS.md` | `…/dotfiles/claude/AGENTS.md` | opencode (beats its `~/.claude/CLAUDE.md` fallback) |

Cursor: **no symlink** (see below).

## Implementation changes

### 1. Repo files
- `git mv claude/CLAUDE.md claude/AGENTS.md` (preserve history; content unchanged).

### 2. `deploy_windows.ps1`
- Repoint the existing Claude `CLAUDE.md` entry: `Source` → `$dotfilesRoot\claude\AGENTS.md`
  (Target stays `$HOME\.claude\CLAUDE.md`).
- Add three `$symlinks` entries (all Source `$dotfilesRoot\claude\AGENTS.md`):
  - Target `$HOME\.claude\AGENTS.md`
  - Target `$HOME\.codex\AGENTS.md`
  - Target `$HOME\.config\opencode\AGENTS.md`
- Confirm the script's link-creation step creates parent dirs (`~/.codex`) — add a `mkdir`/guard
  if it doesn't already.

### 3. `scripts/sync-ai-configs.sh` (covers deploy.sh + setup_mac.sh)
- Remove `CLAUDE.md` from the L28 loop (that loop maps `claude/$item` → `~/.claude/$item`, but the
  source is now `AGENTS.md` while the target name must stay `CLAUDE.md`, so it needs its own line).
- Add explicit `link_config` lines (helper already backs up real files and `mkdir -p`s the target dir):
  - `link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.claude/CLAUDE.md"`
  - `link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.claude/AGENTS.md"`
  - `link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.codex/AGENTS.md"`
  - `link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"`

### 4. Cursor helper (global rules are manual)
- Add `scripts/copy-agents-rules` (small, cross-platform): copies `claude/AGENTS.md` to the
  clipboard (`Set-Clipboard` on Windows, `pbcopy`/`wl-copy`/`xclip` on Unix) so re-syncing Cursor's
  **Settings → Rules → User Rules** after an edit is a 5-second paste.
- Document the one-time manual paste in `DEPLOYMENT.md`.

### 5. Docs
- `DEPLOYMENT.md`: note the canonical `AGENTS.md`, the new home-dir targets, and the Cursor step.
- Repo-root `CLAUDE.md`: update the Windows symlink-mapping table and "Key Configuration Files"
  table (the `claude/ → ~/.claude/` rows) to mention `AGENTS.md` + the Codex/opencode targets.

## Verification

After re-running the deploy script on the current machine (Windows):
1. `Get-Item ~/.claude/CLAUDE.md, ~/.claude/AGENTS.md, ~/.codex/AGENTS.md, ~/.config/opencode/AGENTS.md`
   → all `LinkType: SymbolicLink`, `Target` = `…\dotfiles\claude\AGENTS.md`.
2. `Get-Content ~/.claude/CLAUDE.md` → shows the "Max — Solo Unity Indie Dev" content.
3. Editing `claude/AGENTS.md` is reflected through every link (they resolve to the same inode/path).
4. Cursor: paste once into User Rules; confirm a new Cursor chat honors a distinctive instruction.
5. `-DryRun` (Windows) / re-run on a second machine shows idempotency (no duplicate/backup churn).

## Risks / mitigations
- **Stale `~/.claude/CLAUDE.md`** (currently → `claude/CLAUDE.md`) becomes dangling after the
  `git mv` until deploy re-runs. → Re-run deploy as part of rollout; `link_config`/PS logic repoints.
- **Codex global-file bug** ([#8759](https://github.com/openai/codex/issues/8759)) → ensure a recent
  Codex; the file/path is correct regardless.
- **Cursor drift** — User Rules are a manual copy, so they can lag `AGENTS.md`. → clipboard helper +
  documented step keep it cheap; accepted limitation (Cursor offers no global file).

## Out of scope
- Repo-root `CLAUDE.md`/`AGENTS.md` (project instructions for the dotfiles repo itself).
- Genericizing Claude-specific content.
- Per-project `AGENTS.md` placement for Cursor (available, not part of the global solution).

## Rollback
- `git revert` the change commit, or `git mv claude/AGENTS.md claude/CLAUDE.md` and re-run deploy.
  The added home-dir symlinks are harmless if left; deploy removal would need manual `Remove-Item`/`rm`.

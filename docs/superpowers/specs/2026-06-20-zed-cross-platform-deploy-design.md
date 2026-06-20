# Zed cross-platform deploy + context7 key move + svim disable

**Date:** 2026-06-20
**Status:** Approved design (brainstorming) — pending implementation
**Scope:** dotfiles repo deploy scripts + machine-local shell config. Three small, independent changes.

## Context

Three unrelated hygiene fixes batched into one pass:

1. **`CONTEXT7_API_KEY` is duplicated** — hardcoded in `~/.zshrc:1` *and* present in
   `~/.config/dotfiles/secrets.env:1` (which `zsh/zshrc.sh:19` already sources). The hardcoded copy
   should go.
2. **`zed/settings.json` is Windows-authored** (`pwsh.exe` shell, `SauceCodePro` font) but
   `deploy.sh:376` symlinks it on Unix, regressing macOS/Linux. Zed has no per-OS settings merge, so
   this needs a structural split.
3. **`svim` is installed/linked/started** by `setup_mac.sh` (`:47`, `:82`, `:87`) but unused; it
   should be disabled but kept documented for easy re-enable.

## Goals

- Unix and Windows each deploy a correct, native Zed `settings.json`.
- `CONTEXT7_API_KEY` lives only in `secrets.env`; no plaintext copy in `~/.zshrc`.
- `svim` no longer installed/linked/started on a fresh `setup_mac.sh`, but trivially re-enableable.
- No existing config lost; every change reversible.

## Non-goals

- Rotating the context7 key (recommended separately; needs dashboard access).
- Splitting `zed/keymap.json` per-OS (keybindings are portable; stays shared).
- A Linux-specific Zed file (Linux reuses `settings.unix.json`).

## Change 1 — Move `CONTEXT7_API_KEY`

- **Action:** delete line 1 of `~/.zshrc` (`export CONTEXT7_API_KEY=…`).
- **Why safe:** `~/.zshrc:2` sources `zshrc_manager.sh` → `zshrc.sh:19` sources `secrets.env`, which
  sets the same key. The context7 MCP reads `${CONTEXT7_API_KEY}` from the environment at call time —
  still satisfied.
- **Repo impact:** none (`~/.zshrc` is a machine-local real file, not repo-tracked).
- **Follow-up (out of scope):** rotate the key on the context7 dashboard, then update `secrets.env`
  with the new value. The current key is exposed in chat transcripts.

## Change 2 — Zed cross-platform (two per-OS files)

Repo file layout:

```
zed/
  settings.unix.json     # macOS/Linux
  settings.windows.json  # Windows
  keymap.json            # shared (unchanged)
```

- `settings.unix.json` ← seeded from the current `~/.config/zed/settings.json` reconcile (system
  light/dark theme, `JetBrainsMono Nerd Font` terminal, default shell, `auto_update_extensions.lua =
  false`). Header comment rewritten to note it is the Unix file and that Windows uses
  `settings.windows.json`.
- `settings.windows.json` ← current `zed/settings.json` verbatim (`pwsh.exe` shell,
  `SauceCodePro Nerd Font Mono`). Same header sync note.
- Delete `zed/settings.json`.
- `deploy.sh:376` → `ln -sf "$HOME/dotfiles/zed/settings.unix.json" "$HOME/.config/zed/settings.json"`
- `deploy_windows.ps1:129` → `Source = "$dotfilesRoot\zed\settings.windows.json"` (Target unchanged:
  `$env:APPDATA\Zed\settings.json`).
- Update doc tables in `CLAUDE.md` (Windows symlink mapping + Key Configuration Files) to the per-OS
  names.

**Drift management:** ~25 keys are shared across the two files. A header comment in each names the
other as the sync counterpart. Accepted trade-off vs. a jq base+overlay merge (rejected: breaks the
symlink model and is fragile on the JSONC comments/trailing commas Zed uses).

**Applying on this Mac (optional, separate from the repo edit):** the current
`~/.config/zed/settings.json` is a real file; to adopt the symlink, back it up then `ln -sfn` it to
`zed/settings.unix.json`. Content is identical, so no settings change.

## Change 3 — Disable svim (keep config)

In `setup_mac.sh`:

- `:47` — remove `    svim \` from the `brew install \` list (a `\`-continued line can't be
  inline-commented without breaking continuation). Note the removal in the re-enable comment.
- `:82` — comment out `ln -sf $HOME/dotfiles/.config/svim $HOME/.config/svim`.
- `:87` — comment out `brew services start svim`.
- Group `:82`/`:87` under a header comment:
  `# svim — disabled 2026-06-20 (unused). Re-enable: add "svim" back to the brew install list above + uncomment below.`
- Keep `.config/svim/` in the repo.

## Verification

- `bash -n deploy.sh` and `bash -n setup_mac.sh` — syntax, incl. the brew-list edit.
- Strip JSONC comments and validate both zed files parse (e.g. `node`/`jq` after comment-strip).
- `grep -c CONTEXT7_API_KEY ~/.zshrc` → 0; a fresh shell still has `$CONTEXT7_API_KEY` set (from
  `secrets.env`).
- `grep -n svim setup_mac.sh` — three references commented/removed; brew list still valid.
- Windows: `deploy_windows.ps1 -DryRun` references `settings.windows.json`.

## Rollback

- **Key:** re-add the `export` to `~/.zshrc` (value still in `secrets.env`).
- **Zed:** `git checkout` the repo files; the old `zed/settings.json` remains in git history.
- **svim:** uncomment / re-add the three lines.

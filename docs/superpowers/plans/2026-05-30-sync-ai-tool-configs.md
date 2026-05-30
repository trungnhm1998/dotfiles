# Sync AI Tool Configs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Version-control the authored Claude Code (`~/.claude/`) and opencode (`~/.config/opencode/`) configs in the dotfiles repo, deploy them by symlink on macOS/Linux/Windows, and move the hardcoded `CONTEXT7_API_KEY` into a gitignored env file.

**Architecture:** Authored config files live in the repo (`claude/` and `.config/opencode/opencode.jsonc`) and are symlinked into place by the deploy scripts. The real API key lives only in `~/.config/dotfiles/secrets.env` (gitignored), exported by `zsh/zshrc.sh`, and consumed via env-var interpolation by both tools (`{env:...}` for opencode, `${...}` for Claude Code's MCP header). Claude Code's context7 MCP server is (re)registered idempotently by the deploy scripts since it lives only in the unsynced `~/.claude.json`.

**Tech Stack:** Bash (`deploy.sh`), Zsh (`zsh/zshrc.sh`), PowerShell (`deploy_windows.ps1`), JSONC (opencode), `claude mcp` CLI.

**Reference spec:** `docs/superpowers/specs/2026-05-30-ai-tools-config-sync-design.md`

**Validation note:** This is a config repo with no unit-test framework. "Tests" here are concrete verification commands (`bash -n`, `shellcheck`, symlink/`readlink` checks, `grep`, `claude mcp list`). Each task ends with a commit. The branch `feat/sync-ai-tool-configs` already exists and holds the spec.

---

### Task 1: Secrets foundation

Create the gitignored secrets convention so later tasks can rely on `$CONTEXT7_API_KEY`.

**Files:**
- Create: `secrets.env.example` (repo root)
- Modify: `.gitignore` (repo root, append a section)
- Modify: `zsh/zshrc.sh:16` (add source line after the `COLORTERM` export)
- Create (local, NOT in repo): `~/.config/dotfiles/secrets.env`

- [ ] **Step 1: Create the committed template**

Create `secrets.env.example`:

```bash
# Secrets template — copy to ~/.config/dotfiles/secrets.env and fill in real values.
# Sourced by zsh/zshrc.sh. Consumed by:
#   - opencode  -> opencode.jsonc reads {env:CONTEXT7_API_KEY}
#   - Claude Code -> ~/.claude.json MCP header reads ${CONTEXT7_API_KEY}
# Never commit the real secrets.env (it lives outside the repo and is gitignored).

export CONTEXT7_API_KEY="ctx7sk-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

- [ ] **Step 2: Add gitignore guard**

Append to `.gitignore`:

```gitignore

# Secrets (defense-in-depth; real secrets live in ~/.config/dotfiles/secrets.env, outside the repo)
secrets.env
**/settings.local.json
```

- [ ] **Step 3: Source secrets from zsh**

In `zsh/zshrc.sh`, immediately after line 16 (`export COLORTERM=truecolor`), insert:

```zsh

# --- secrets (gitignored; see secrets.env.example) ---
[ -f "$HOME/.config/dotfiles/secrets.env" ] && source "$HOME/.config/dotfiles/secrets.env"
```

- [ ] **Step 4: Create the real local secrets file**

Use the real key currently stored in `~/.claude.json` (read it, do not hardcode here):

```bash
mkdir -p "$HOME/.config/dotfiles"
KEY=$(python3 -c "import json;print(json.load(open('$HOME/.claude.json'))['mcpServers']['context7']['headers']['CONTEXT7_API_KEY'])")
printf 'export CONTEXT7_API_KEY="%s"\n' "$KEY" > "$HOME/.config/dotfiles/secrets.env"
chmod 600 "$HOME/.config/dotfiles/secrets.env"
```

- [ ] **Step 5: Verify the env var loads in a fresh shell**

Run: `zsh -ic 'echo "KEY=${CONTEXT7_API_KEY:0:7}"'`
Expected: prints `KEY=ctx7sk-` (confirms sourcing works; only the prefix is shown).

- [ ] **Step 6: Verify the secret is not tracked**

Run: `git -C "$HOME/dotfiles" status --porcelain && git -C "$HOME/dotfiles" check-ignore secrets.env`
Expected: status shows only `secrets.env.example`, `.gitignore`, `zsh/zshrc.sh` (NOT any `secrets.env`); `check-ignore` prints `secrets.env`.

- [ ] **Step 7: Commit**

```bash
git add secrets.env.example .gitignore zsh/zshrc.sh
git commit -m "feat(secrets): add gitignored env file convention for API keys"
```

---

### Task 2: Migrate opencode config to JSONC

Move opencode's config into the repo as `.jsonc`, replace the live file with a symlink, and delete the stale `.json` so it can't shadow/merge.

**Files:**
- Create: `.config/opencode/opencode.jsonc` (repo)
- Delete (live): `~/.config/opencode/opencode.json`
- Symlink: `~/.config/opencode/opencode.jsonc` -> repo

- [ ] **Step 1: Create the JSONC config in the repo**

Create `.config/opencode/opencode.jsonc` (same servers as the current `opencode.json`, now with comments; `context7` already uses `{env:...}` — keep it):

```jsonc
{
  // opencode config — synced via dotfiles. https://opencode.ai/docs/config/
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    // Local Unity MCP bridge — only reachable when the Unity Editor bridge is running.
    "unityMCP": {
      "type": "remote",
      "url": "http://127.0.0.1:8080/mcp",
      "enabled": true
    },
    // context7 docs MCP — key injected from $CONTEXT7_API_KEY (see ~/.config/dotfiles/secrets.env).
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": true,
      "headers": {
        "CONTEXT7_API_KEY": "{env:CONTEXT7_API_KEY}"
      }
    }
  }
}
```

- [ ] **Step 2: Verify the JSONC parses (comments stripped)**

Run:
```bash
python3 -c "import re,json,sys; t=open('$HOME/dotfiles/.config/opencode/opencode.jsonc').read(); t=re.sub(r'//.*','',t); json.loads(t); print('OK')"
```
Expected: prints `OK` (validates structure ignoring `//` comments).

- [ ] **Step 3: Replace the live file with a symlink and delete the stale .json**

```bash
rm -f "$HOME/.config/opencode/opencode.json"
ln -sfn "$HOME/dotfiles/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
```

- [ ] **Step 4: Verify the symlink resolves and old .json is gone**

Run: `ls -la "$HOME/.config/opencode/" | grep opencode`
Expected: `opencode.jsonc -> .../dotfiles/.config/opencode/opencode.jsonc`; no `opencode.json` present.

- [ ] **Step 5: Commit**

```bash
git add .config/opencode/opencode.jsonc
git commit -m "feat(opencode): track config as commented opencode.jsonc"
```

---

### Task 3: Migrate Claude Code authored config + fix hook path

Copy the authored Claude Code files into the repo, fix the hardcoded hook command, then replace the live files/dirs with symlinks.

**Files:**
- Create (repo): `claude/CLAUDE.md`, `claude/settings.json`, `claude/statusline.sh`, `claude/statusline-command.sh`, `claude/agents/`, `claude/commands/`, `claude/hooks/`, `claude/skills/`
- Modify: `claude/settings.json` (hook command string)
- Symlink: the same paths back into `~/.claude/`

- [ ] **Step 1: Copy authored files into the repo (dereferencing any symlinks)**

```bash
cd "$HOME/dotfiles"
mkdir -p claude
cp -RL "$HOME/.claude/CLAUDE.md" claude/CLAUDE.md
cp -RL "$HOME/.claude/settings.json" claude/settings.json
cp -RL "$HOME/.claude/statusline.sh" claude/statusline.sh
cp -RL "$HOME/.claude/statusline-command.sh" claude/statusline-command.sh
cp -RL "$HOME/.claude/agents" claude/agents
cp -RL "$HOME/.claude/commands" claude/commands
cp -RL "$HOME/.claude/hooks" claude/hooks
cp -RL "$HOME/.claude/skills" claude/skills
```

- [ ] **Step 2: Fix the hardcoded hook command in the repo's settings.json**

In `claude/settings.json`, change the SessionStart hook command from:

```json
"command": "/bin/bash /Users/trungnhm1998/.claude/hooks/unity-project-detect.sh"
```

to:

```json
"command": "bash ~/.claude/hooks/unity-project-detect.sh"
```

- [ ] **Step 3: Verify settings.json is still valid JSON and the path is portable**

Run:
```bash
python3 -c "import json;print('OK' if 'bash ~/.claude/hooks' in json.load(open('$HOME/dotfiles/claude/settings.json'))['hooks']['SessionStart'][0]['hooks'][0]['command'] else 'BAD')"
```
Expected: prints `OK`.

- [ ] **Step 4: Replace live files/dirs with symlinks (back up originals)**

```bash
cd "$HOME/dotfiles"
for item in CLAUDE.md settings.json statusline.sh statusline-command.sh agents commands hooks skills; do
  tgt="$HOME/.claude/$item"
  [ -e "$tgt" ] && [ ! -L "$tgt" ] && mv "$tgt" "${tgt}.old"
  ln -sfn "$HOME/dotfiles/claude/$item" "$tgt"
done
```

- [ ] **Step 5: Verify symlinks resolve**

Run: `ls -la "$HOME/.claude/" | grep -E 'CLAUDE.md|settings.json|agents|commands|hooks|skills|statusline'`
Expected: each entry shows `-> .../dotfiles/claude/...`.

- [ ] **Step 6: Verify the hook still runs from a Unity project dir (and no-ops elsewhere)**

Run:
```bash
CLAUDE_PROJECT_DIR=/tmp bash ~/.claude/hooks/unity-project-detect.sh; echo "exit=$?"
```
Expected: no output, `exit=0` (cwd `/tmp` is not a Unity project — silent skip confirms the script is reachable via the symlink).

- [ ] **Step 7: Commit**

```bash
git add claude/
git commit -m "feat(claude): track authored config (agents, commands, hooks, skills, settings)"
```

---

### Task 4: Refactor the context7 credential out of ~/.claude.json

Re-register the context7 MCP server so `~/.claude.json` holds the `${CONTEXT7_API_KEY}` placeholder instead of the literal key.

**Files:**
- Modify (live, not tracked): `~/.claude.json` (via `claude mcp` CLI)

- [ ] **Step 1: Confirm the literal key is currently present (the thing we're removing)**

Run:
```bash
python3 -c "print(json.load(open('$HOME/.claude.json'))['mcpServers']['context7']['headers']['CONTEXT7_API_KEY'][:7])" 2>/dev/null || \
python3 -c "import json;print(json.load(open('$HOME/.claude.json'))['mcpServers']['context7']['headers']['CONTEXT7_API_KEY'][:7])"
```
Expected: prints `ctx7sk-` (literal key present — this is what we scrub).

- [ ] **Step 2: Re-register with the placeholder (single quotes preserve `${...}`)**

```bash
claude mcp remove context7 --scope user 2>/dev/null || true
claude mcp add --scope user --transport http context7 \
  https://mcp.context7.com/mcp \
  --header 'CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}'
```

- [ ] **Step 3: Verify ~/.claude.json now holds the placeholder, not the key**

Run:
```bash
python3 -c "import json;v=json.load(open('$HOME/.claude.json'))['mcpServers']['context7']['headers']['CONTEXT7_API_KEY'];print('OK' if v=='\${CONTEXT7_API_KEY}' else 'STILL LITERAL: '+v[:10])"
```
Expected: prints `OK`.

- [ ] **Step 4: Verify the server is registered**

Run: `claude mcp list | grep context7`
Expected: a line showing `context7` with the `https://mcp.context7.com/mcp` URL.

- [ ] **Step 5: No commit**

This task only changes the unsynced `~/.claude.json`. Nothing to commit. (The reproducible version of this step is added to the deploy scripts in Tasks 5–6.)

---

### Task 5: Wire the unix deploy script (deploy.sh)

Make the migration reproducible on fresh macOS/Linux machines.

**Files:**
- Modify: `deploy.sh` (add helper near line 137; add config block after line 377; add bootstrap + mcp registration before `check_default_shell` at line 379)

- [ ] **Step 1: Add the `link_config` helper**

In `deploy.sh`, after the `check_default_shell()` function (after line 137), add:

```bash
# Symlink a repo config into place. If the target is a real file/dir, back it up first.
# Uses -n so a directory symlink never gets created *inside* an existing dir.
# Usage: link_config <source-in-repo> <target>
link_config() {
	local src="$1" target="$2"
	if [ -L "$target" ]; then
		ln -sfn "$src" "$target"
		return
	fi
	if [ -e "$target" ]; then
		echo "Backing up existing $target -> ${target}.old"
		mv "$target" "${target}.old"
	fi
	mkdir -p "$(dirname "$target")"
	ln -sfn "$src" "$target"
}
```

- [ ] **Step 2: Add the AI-config symlink + secrets + MCP block**

In `deploy.sh`, immediately after the existing symlink block (after line 377, the `zed/keymap.json` line), add:

```bash

# --- AI tool configs: Claude Code + opencode ---
for item in CLAUDE.md settings.json statusline.sh statusline-command.sh agents commands hooks skills; do
	link_config "$HOME/dotfiles/claude/$item" "$HOME/.claude/$item"
done

# opencode: track only opencode.jsonc; remove stale opencode.json (loaded first, would shadow/merge)
rm -f "$HOME/.config/opencode/opencode.json"
link_config "$HOME/dotfiles/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"

# Bootstrap the gitignored secrets file from the template if it's missing
if [ ! -f "$HOME/.config/dotfiles/secrets.env" ]; then
	mkdir -p "$HOME/.config/dotfiles"
	cp "$HOME/dotfiles/secrets.env.example" "$HOME/.config/dotfiles/secrets.env"
	chmod 600 "$HOME/.config/dotfiles/secrets.env"
	echo "Created ~/.config/dotfiles/secrets.env — edit it and fill in CONTEXT7_API_KEY."
fi

# Register context7 MCP for Claude Code (idempotent). Key injected at session time via ${CONTEXT7_API_KEY}.
if [ -x "$(command -v claude)" ]; then
	claude mcp remove context7 --scope user 2>/dev/null || true
	claude mcp add --scope user --transport http context7 \
		https://mcp.context7.com/mcp \
		--header 'CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}'
fi
```

- [ ] **Step 3: Syntax-check the script**

Run: `bash -n "$HOME/dotfiles/deploy.sh" && echo SYNTAX_OK`
Expected: prints `SYNTAX_OK`.

- [ ] **Step 4: Lint with shellcheck**

Run: `shellcheck -S warning "$HOME/dotfiles/deploy.sh" | grep -E 'link_config|context7|opencode|secrets' || echo "no new findings in added block"`
Expected: `no new findings in added block` (pre-existing warnings elsewhere are out of scope).

- [ ] **Step 5: Verify idempotency (re-running link_config is a no-op on this already-migrated machine)**

Run:
```bash
source <(sed -n '/^link_config()/,/^}/p' "$HOME/dotfiles/deploy.sh")
link_config "$HOME/dotfiles/claude/agents" "$HOME/.claude/agents"
readlink "$HOME/.claude/agents"
```
Expected: prints `.../dotfiles/claude/agents` and creates no `agents.old` and no nested `agents/agents`.

- [ ] **Step 6: Commit**

```bash
git add deploy.sh
git commit -m "feat(deploy): symlink Claude/opencode configs, bootstrap secrets, register context7 MCP"
```

---

### Task 6: Wire the Windows deploy script (deploy_windows.ps1)

Implement the same on Windows. Verification is deferred to a Windows machine (per scope), but the code is complete.

**Files:**
- Modify: `deploy_windows.ps1` (`$symlinks` array near line 70; env-var section near line 494; add a secrets + MCP block)

- [ ] **Step 1: Read the exact `$symlinks` element shape first**

Run: `sed -n '70,140p' "$HOME/dotfiles/deploy_windows.ps1"`
Expected: shows the hashtable keys actually used (e.g. `Name`, `Source`, `Target`, `Type`). Match that shape exactly in Step 2 (the example below assumes `Source`/`Target`; add any other keys the file uses).

- [ ] **Step 2: Add AI-config entries to the `$symlinks` array**

Inside the `$symlinks = @( ... )` array, add (adjusting keys to match Step 1):

```powershell
    # --- Claude Code (authored config) ---
    @{ Source = "$dotfilesRoot\claude\CLAUDE.md";             Target = "$HOME\.claude\CLAUDE.md" }
    @{ Source = "$dotfilesRoot\claude\settings.json";         Target = "$HOME\.claude\settings.json" }
    @{ Source = "$dotfilesRoot\claude\statusline.sh";         Target = "$HOME\.claude\statusline.sh" }
    @{ Source = "$dotfilesRoot\claude\statusline-command.sh"; Target = "$HOME\.claude\statusline-command.sh" }
    @{ Source = "$dotfilesRoot\claude\agents";                Target = "$HOME\.claude\agents" }
    @{ Source = "$dotfilesRoot\claude\commands";              Target = "$HOME\.claude\commands" }
    @{ Source = "$dotfilesRoot\claude\hooks";                 Target = "$HOME\.claude\hooks" }
    @{ Source = "$dotfilesRoot\claude\skills";                Target = "$HOME\.claude\skills" }
    # --- opencode (XDG path on Windows: ~\.config\opencode) ---
    @{ Source = "$dotfilesRoot\.config\opencode\opencode.jsonc"; Target = "$HOME\.config\opencode\opencode.jsonc" }
```

- [ ] **Step 3: Delete the stale opencode.json before the symlink loop**

Immediately before the `foreach ($link in $symlinks)` loop (near line 480), add:

```powershell
# opencode: remove stale opencode.json so it can't shadow/merge with the tracked .jsonc
$staleOpencode = "$HOME\.config\opencode\opencode.json"
if (Test-Path $staleOpencode) {
    if ($DryRun) { Write-Host "  [DRY RUN] Would remove: $staleOpencode" -ForegroundColor DarkGray }
    else { Remove-Item -Path $staleOpencode -Force }
}
```

- [ ] **Step 4: Set CONTEXT7_API_KEY env var from secrets and register the MCP server**

After the env-var section (after line ~495 where `XDG_CONFIG_HOME` is set), add:

```powershell
# --- AI tool secrets + context7 MCP registration ---
$secretsFile = "$HOME\.config\dotfiles\secrets.env"
if (Test-Path $secretsFile) {
    # Parse `export KEY="value"` lines and set them as user env vars
    Get-Content $secretsFile | ForEach-Object {
        if ($_ -match '^\s*export\s+([A-Z_][A-Z0-9_]*)\s*=\s*"?([^"]*)"?\s*$') {
            $name = $Matches[1]; $value = $Matches[2]
            if ($DryRun) { Write-Host "  [DRY RUN] Would set env $name" -ForegroundColor DarkGray }
            else { [Environment]::SetEnvironmentVariable($name, $value, "User"); Set-Item "env:$name" $value }
        }
    }
} else {
    New-Item -ItemType Directory -Path "$HOME\.config\dotfiles" -Force | Out-Null
    Copy-Item "$dotfilesRoot\secrets.env.example" $secretsFile
    Write-Status "Created $secretsFile - fill in CONTEXT7_API_KEY." -Type Warning
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would (re)register context7 MCP server" -ForegroundColor DarkGray
    } else {
        claude mcp remove context7 --scope user 2>$null
        claude mcp add --scope user --transport http context7 `
            https://mcp.context7.com/mcp `
            --header 'CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}'
    }
}
```

- [ ] **Step 5: Best-effort syntax check (parser only; full run is Windows-only)**

Run (on macOS, if `pwsh` is available; otherwise skip and note it):
```bash
command -v pwsh >/dev/null && pwsh -NoProfile -Command "\$null = [System.Management.Automation.Language.Parser]::ParseFile('$HOME/dotfiles/deploy_windows.ps1', [ref]\$null, [ref]\$e); if (\$e) { \$e } else { 'PARSE_OK' }" || echo "pwsh not installed — defer parse check to Windows"
```
Expected: `PARSE_OK`, or the skip message. Real verification (symlinks, env var, `claude mcp list`) happens on a Windows machine.

- [ ] **Step 6: Commit**

```bash
git add deploy_windows.ps1
git commit -m "feat(deploy-windows): symlink Claude/opencode configs, set secrets env, register context7 MCP"
```

---

### Task 7: Update documentation

Document the new mappings and secrets convention.

**Files:**
- Modify: `CLAUDE.md` (Windows Symlink Mappings table + Key Configuration Files table)
- Modify: `AGENTS.md` (Key File Locations table)

- [ ] **Step 1: Add rows to the Windows Symlink Mappings table in `CLAUDE.md`**

Under the `### Windows Symlink Mappings` table, add:

```markdown
| `claude/` (CLAUDE.md, settings.json, agents, commands, hooks, skills, statusline*) | `$HOME\.claude\…` |
| `.config/opencode/opencode.jsonc` | `$HOME\.config\opencode\opencode.jsonc` |
```

- [ ] **Step 2: Add rows to the Key Configuration Files table in `CLAUDE.md`**

```markdown
| Claude Code | `claude/` → `~/.claude/` |
| opencode | `.config/opencode/opencode.jsonc` |
| Secrets (gitignored) | `~/.config/dotfiles/secrets.env` (template: `secrets.env.example`) |
```

- [ ] **Step 3: Add rows to the Key File Locations table in `AGENTS.md`**

```markdown
| Claude Code Config | `claude/` (→ `~/.claude/`) |
| opencode Config | `.config/opencode/opencode.jsonc` |
| Secrets template | `secrets.env.example` (real values in `~/.config/dotfiles/secrets.env`, gitignored) |
```

- [ ] **Step 4: Verify the docs render (no broken tables)**

Run: `grep -n "opencode.jsonc\|secrets.env\|claude/" "$HOME/dotfiles/CLAUDE.md" "$HOME/dotfiles/AGENTS.md"`
Expected: shows the newly added rows in both files.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md AGENTS.md
git commit -m "docs: document Claude/opencode config sync and secrets convention"
```

---

## Self-Review

**Spec coverage:**
- Tracked Claude files (CLAUDE.md, settings.json, agents/commands/hooks/skills, statusline*) → Task 3. ✓
- opencode `.jsonc` rename + stale `.json` deletion → Task 2 (live) + Tasks 5/6 (deploy). ✓
- Excluded state/cache → never touched (only authored paths are copied). ✓
- Symlink deploy method → `link_config` (Task 5), `$symlinks` array (Task 6). ✓
- Secrets in gitignored env file + template + zsh sourcing → Task 1. ✓
- Credential refactor (placeholder in `~/.claude.json`) → Task 4 (live) + Tasks 5/6 (deploy). ✓
- Cross-platform hook (`bash ~/.claude/hooks/...`) → Task 3 Step 2. ✓
- All three platforms → Tasks 5 (mac/linux) + 6 (windows). ✓
- Docs updated → Task 7. ✓
- Key rotation → advisory, out of plan scope (noted in spec).

**Placeholder scan:** No TBD/TODO; all code blocks complete; the only intentional placeholder is the dummy `ctx7sk-xxxx...` in `secrets.env.example`, which is correct (it's a template).

**Type/name consistency:** `link_config <src> <target>` signature is identical in Tasks 5 Step 1/2/5. The env var `CONTEXT7_API_KEY`, the MCP server name `context7`, the placeholder string `${CONTEXT7_API_KEY}`, and the secrets path `~/.config/dotfiles/secrets.env` are spelled consistently across all tasks and match the spec.

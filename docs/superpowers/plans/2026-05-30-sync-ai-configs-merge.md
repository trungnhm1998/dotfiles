# Sync AI Configs (Claude Code + opencode) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Union-merge the live Windows Claude Code + opencode configs into the dotfiles repo, make `deploy_windows.ps1` safe (preserve plugin junctions, externalize the proxy + secrets), then migrate this machine.

**Architecture:** Hybrid symlink strategy — whole-dir symlinks for `agents/`+`commands/` (after union'ing content into the repo), per-item symlinks for `skills/` (to preserve plugin junctions). `settings.json` is symlinked portable-only; the Windows proxy moves to an OS env var and the notify hook moves to a cross-platform hook script. `opencode.jsonc` adopts the live config with its API key externalized. Live wins on every genuine collision.

**Tech Stack:** PowerShell 7 (`deploy_windows.ps1`), bash hook scripts, JSON/JSONC config, git. Spec: `docs/superpowers/specs/2026-05-30-sync-ai-configs-merge-design.md`.

**Validation note:** This is a config repo with no test framework. "Tests" here are validation commands: JSON parsing, `bash -n` / PowerShell syntax checks, secret-leak greps, and symlink/junction inspection. Run all `git`/`bash` steps from the repo root `C:\Users\mint\dotfiles` (the Bash tool's cwd).

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `claude/agents/*.md` | Union of 10 agents (3 dotfiles + 7 live; `unity-code-reviewer` → live) | Add 7 files |
| `claude/commands/*.md` | Union of 8 commands (4 dotfiles + 4 live; `learn` → live) | Add 4 files |
| `claude/hooks/claude-notify.sh` | Cross-platform Notification hook (Windows → `claude-notify.ps1`, else no-op) | Create |
| `claude/settings.json` | Portable, machine-agnostic Claude settings (no proxy/env, notify via script) | Rewrite |
| `claude/CLAUDE.md` | Minimal indie-dev persona + one deprecated-API line | Append 1 line |
| `.config/opencode/opencode.jsonc` | Live opencode config, API key externalized, duplicate `agent` key merged | Rewrite |
| `secrets.env.example` | Add `NINEROUTER_API_KEY` placeholder | Modify |
| `deploy_windows.ps1` | Per-item skills symlink loop; `ANTHROPIC_BASE_URL` Windows env var | Modify |

---

## Phase A — Repo-side content (no live-machine impact)

### Task 1: Union Claude agents into the repo

**Files:**
- Create: `claude/agents/{engine-docs-researcher,game-debugger,game-design-critic,gameplay-test-writer,perf-optimizer,shader-graphics-specialist}.md`
- Modify: `claude/agents/unity-code-reviewer.md` (overwrite with live — collision → live)

- [ ] **Step 1: Copy the 6 live-only agents + overwrite the collision from live**

```bash
cd ~/dotfiles
for a in engine-docs-researcher game-debugger game-design-critic gameplay-test-writer perf-optimizer shader-graphics-specialist unity-code-reviewer; do
  cp -f ~/.claude/agents/$a.md claude/agents/$a.md
done
```

- [ ] **Step 2: Verify the union is exactly 10 agents and every one has a `color:`**

Run:
```bash
cd ~/dotfiles
ls claude/agents | wc -l            # expect 10
for f in claude/agents/*.md; do grep -qE '^color:' "$f" || echo "MISSING color: $f"; done
```
Expected: `10`, and no `MISSING color` lines. (If any file prints MISSING, add a `color: blue` line into its `---` frontmatter before continuing.)

- [ ] **Step 3: Verify each agent has valid frontmatter (`name:` present)**

Run:
```bash
cd ~/dotfiles
for f in claude/agents/*.md; do head -1 "$f" | grep -q '^---' || echo "BAD frontmatter: $f"; done
```
Expected: no output.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add claude/agents/
git commit -m "feat(claude): union live Unity agents into dotfiles (live wins on unity-code-reviewer)"
```

---

### Task 2: Union Claude commands into the repo

**Files:**
- Create: `claude/commands/{design,implement,review}.md`
- Modify: `claude/commands/learn.md` (overwrite with live — collision → live)

- [ ] **Step 1: Copy the 3 live-only commands + overwrite the collision from live**

```bash
cd ~/dotfiles
for c in design implement review learn; do
  cp -f ~/.claude/commands/$c.md claude/commands/$c.md
done
```

- [ ] **Step 2: Verify the union is exactly 8 commands**

Run:
```bash
cd ~/dotfiles
ls claude/commands | sort | tr '\n' ' '; echo
```
Expected: `design.md implement.md learn.md new-game.md review.md scope-check.md unity-review.md verify-api.md`

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add claude/commands/
git commit -m "feat(claude): union live commands into dotfiles (live wins on learn)"
```

---

### Task 3: Adopt the live `opencode.jsonc`, sanitized

**Files:**
- Modify: `.config/opencode/opencode.jsonc` (replace 20-line stub with sanitized live config)
- Modify: `secrets.env.example` (add `NINEROUTER_API_KEY`)

- [ ] **Step 1: Copy the live config over the repo stub**

```bash
cd ~/dotfiles
cp -f ~/.config/opencode/opencode.jsonc .config/opencode/opencode.jsonc
```

- [ ] **Step 2: Externalize the hardcoded API key**

Edit `.config/opencode/opencode.jsonc`. Replace the literal key line:

```jsonc
      "apiKey": "sk-e13bde9f6291ddc7-lb2bqk-8d6f33d6",
```

with:

```jsonc
      "apiKey": "{env:NINEROUTER_API_KEY}",
```

- [ ] **Step 3: Consolidate the duplicate `"agent"` key**

The live file has TWO `"agent"` blocks (invalid — last-wins silently). The first (near the top) holds `title`/`build`/`plan`; the second (near the bottom) holds `explorer`. Merge them: move `explorer` into the FIRST block and DELETE the second block.

Change the first block from:

```jsonc
  "agent": {
    "title": {
      "model": "9router/cu/claude-4.5-haiku",
    },
    "build": {
      "enable1mContext": true,
    },
    "plan": {
      "enable1mContext": true,
    },
  },
```

to:

```jsonc
  "agent": {
    "title": {
      "model": "9router/cu/claude-4.5-haiku",
    },
    "build": {
      "enable1mContext": true,
    },
    "plan": {
      "enable1mContext": true,
    },
    "explorer": {
      "description": "Fast explorer subagent for codebase exploration",
      "mode": "subagent",
      "model": "9router/cu/default",
    },
  },
```

Then DELETE the now-duplicate trailing block (just before the final closing `}`):

```jsonc
  "agent": {
    "explorer": {
      "description": "Fast explorer subagent for codebase exploration",
      "mode": "subagent",
      "model": "9router/cu/default",
    },
  },
```

- [ ] **Step 4: Verify no secret remains and the env reference is present**

Run:
```bash
cd ~/dotfiles
grep -n 'sk-e13b' .config/opencode/opencode.jsonc && echo "LEAK!" || echo "no raw key — good"
grep -c '{env:NINEROUTER_API_KEY}' .config/opencode/opencode.jsonc   # expect 1
grep -c '"agent"' .config/opencode/opencode.jsonc                    # expect 1 (deduped)
```
Expected: `no raw key — good`, then `1`, then `1`.

- [ ] **Step 5: Verify brace/bracket balance (lenient JSONC sanity check)**

Run:
```bash
cd ~/dotfiles
node -e "const s=require('fs').readFileSync('.config/opencode/opencode.jsonc','utf8'); const o=(s.match(/{/g)||[]).length,c=(s.match(/}/g)||[]).length,b=(s.match(/\[/g)||[]).length,d=(s.match(/]/g)||[]).length; console.log('braces',o,c,'brackets',b,d); process.exit(o===c&&b===d?0:1)"
```
Expected: `braces N N brackets M M` with matching counts (exit 0). (opencode validates the full JSONC itself at Task 11.)

- [ ] **Step 6: Add the secret placeholder to the example file**

Append to `secrets.env.example`:

```bash
export NINEROUTER_API_KEY="sk-xxxxxxxxxxxxxxxx-xxxxxx-xxxxxxxx"
```

Also extend the header comment's "Consumed by" list to mention opencode's `9router` provider.

- [ ] **Step 7: Commit**

```bash
cd ~/dotfiles
git add .config/opencode/opencode.jsonc secrets.env.example
git commit -m "feat(opencode): adopt live config; externalize 9router key to NINEROUTER_API_KEY; dedupe agent block"
```

---

### Task 4: Create the cross-platform notify hook

**Files:**
- Create: `claude/hooks/claude-notify.sh`

- [ ] **Step 1: Write the hook script**

Create `claude/hooks/claude-notify.sh`:

```bash
#!/usr/bin/env bash
# Cross-platform Claude Code Notification hook.
# Reads the hook JSON payload on stdin and surfaces .message as a desktop notification.
# Windows: delegates to the machine-local C:\Tools\claude-notify.ps1 (passes the wezterm pane id).
# macOS:   uses osascript if available. Linux: uses notify-send if available. Otherwise no-op.

payload="$(cat)"
message="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
[ -z "$message" ] && exit 0

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    notifier="/c/Tools/claude-notify.ps1"
    if [ -f "$notifier" ]; then
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Tools\\claude-notify.ps1" \
        -Title "Claude Code" -Message "$message" -PaneId "${WEZTERM_PANE:-}"
    fi
    ;;
  Darwin)
    command -v osascript >/dev/null 2>&1 && \
      osascript -e "display notification \"${message//\"/\\\"}\" with title \"Claude Code\""
    ;;
  *)
    command -v notify-send >/dev/null 2>&1 && notify-send "Claude Code" "$message"
    ;;
esac
exit 0
```

- [ ] **Step 2: Mark it executable and syntax-check it**

Run:
```bash
cd ~/dotfiles
chmod +x claude/hooks/claude-notify.sh
bash -n claude/hooks/claude-notify.sh && echo "syntax OK"
```
Expected: `syntax OK`.

- [ ] **Step 3: Smoke-test the message extraction (no notification expected to fire in CI/non-Windows)**

Run:
```bash
cd ~/dotfiles
echo '{"message":"hello from test"}' | bash claude/hooks/claude-notify.sh; echo "exit=$?"
```
Expected: `exit=0` (on Windows it also pops a notification via `claude-notify.ps1`; that's fine).

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add claude/hooks/claude-notify.sh
git commit -m "feat(claude): cross-platform claude-notify.sh hook (Windows ps1 / osascript / notify-send)"
```

---

### Task 5: Rewrite `claude/settings.json` as portable-only

**Files:**
- Modify: `claude/settings.json`

- [ ] **Step 1: Write the merged portable settings**

Replace the entire contents of `claude/settings.json` with:

```json
{
  "permissions": {
    "allow": [],
    "deny": [],
    "defaultMode": "auto"
  },
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/unity-project-detect.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/claude-notify.sh"
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "bunx -y ccstatusline@latest",
    "padding": 0,
    "refreshInterval": 10
  },
  "enabledPlugins": {
    "everything-claude-code@everything-claude-code": false,
    "claude-mem@thedotmack": false,
    "lua-lsp@claude-plugins-official": false,
    "superpowers@claude-plugins-official": true
  },
  "effortLevel": "high",
  "awaySummaryEnabled": false,
  "autoUpdatesChannel": "latest",
  "theme": "dark-ansi",
  "editorMode": "vim",
  "verbose": true,
  "agentPushNotifEnabled": true,
  "skipAutoPermissionPrompt": true
}
```

> Note: the live `env.ANTHROPIC_BASE_URL` proxy and the direct PowerShell notify hook are intentionally **absent** — proxy moves to an OS env var (Task 7), notify moves to the script (Task 4). Live's `superpowers@claude-plugins-official` plugin source is kept; the dotfiles `extraKnownMarketplaces`/`obra` source is dropped (single source).

- [ ] **Step 2: Validate it is strict, parseable JSON**

Run:
```bash
cd ~/dotfiles
pwsh -NoProfile -Command "Get-Content claude/settings.json -Raw | ConvertFrom-Json | Out-Null; if (\$?) { 'JSON OK' }"
```
Expected: `JSON OK`.

- [ ] **Step 3: Confirm no proxy/secret leaked into the portable file**

Run:
```bash
cd ~/dotfiles
grep -nE 'ANTHROPIC_BASE_URL|localhost:8080|C:\\\\Tools' claude/settings.json && echo "LEAK!" || echo "clean — good"
```
Expected: `clean — good`.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add claude/settings.json
git commit -m "feat(claude): portable settings.json (proxy->env var, notify->script, keep live plugins + add SessionStart)"
```

---

### Task 6: Add the deprecated-API guardrail to `CLAUDE.md`

**Files:**
- Modify: `claude/CLAUDE.md`

- [ ] **Step 1: Append one line under the engineering defaults**

In `claude/CLAUDE.md`, add this bullet to the end of the `## Engineering defaults (Unity / C#)` section:

```markdown
- Avoid deprecated Unity APIs (`OnGUI`, `WWW`, legacy `Input` manager) — prefer UI Toolkit / `UnityWebRequest` / the new Input System.
```

- [ ] **Step 2: Verify it landed and the file still starts with the indie-dev heading**

Run:
```bash
cd ~/dotfiles
head -1 claude/CLAUDE.md                       # expect: # Trung — Solo Unity Indie Dev
grep -c 'deprecated Unity APIs' claude/CLAUDE.md   # expect 1
```
Expected: heading line, then `1`.

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add claude/CLAUDE.md
git commit -m "docs(claude): warn against deprecated Unity APIs in global instructions"
```

---

## Phase B — `deploy_windows.ps1` changes

### Task 7: Per-item skills symlink + `ANTHROPIC_BASE_URL` env var

**Files:**
- Modify: `deploy_windows.ps1` (remove whole-dir skills entry; add per-item loop; add env var)

- [ ] **Step 1: Remove the whole-dir `skills` symlink entry**

Delete this entry from the `$symlinks` array (around lines 184–189):

```powershell
    @{
        Source      = "$dotfilesRoot\claude\skills"
        Target      = "$HOME\.claude\skills"
        IsDirectory = $true
        Description = "Claude Code skills"
    }
```

- [ ] **Step 2: Add a per-item skills symlink loop after the main symlink `foreach`**

Immediately AFTER the `foreach ($link in $symlinks) { ... }` block (after line ~549, still inside `if (-not $SkipSymlinks)`), insert:

```powershell
    # Claude skills: per-item symlinks so we never clobber plugin-managed junctions.
    # Link each repo skill into ~/.claude/skills/<name> ONLY if that name is free.
    Write-Host "`nLinking: Claude Code skills (per-item, preserving plugin junctions)" -ForegroundColor Cyan
    $skillsSrcDir = "$dotfilesRoot\claude\skills"
    $skillsDstDir = "$HOME\.claude\skills"
    if (Test-Path $skillsSrcDir) {
        if (-not (Test-Path $skillsDstDir)) {
            if ($DryRun) { Write-Host "  [DRY RUN] Would create directory: $skillsDstDir" -ForegroundColor DarkGray }
            else { New-Item -ItemType Directory -Path $skillsDstDir -Force | Out-Null }
        }
        foreach ($skill in Get-ChildItem -Path $skillsSrcDir -Directory) {
            $dst = Join-Path $skillsDstDir $skill.Name
            if (Test-Path $dst) {
                Write-Status "Skill '$($skill.Name)' already present (left as-is)" -Type Success
                continue
            }
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would create symlink: $dst -> $($skill.FullName)" -ForegroundColor DarkGray
            } else {
                New-Item -ItemType SymbolicLink -Path $dst -Value $skill.FullName -Force | Out-Null
                Write-Status "Linked skill: $($skill.Name)" -Type Success
            }
        }
    }
```

- [ ] **Step 3: Add the Windows-only proxy env var**

In the `$envVars` hashtable (around line 558), add the proxy entry:

```powershell
$envVars = @{
    "KOMOREBI_CONFIG_HOME" = "$HOME\.config\komorebi"
    "XDG_CONFIG_HOME"      = "$HOME\.config"
    "ANTHROPIC_BASE_URL"   = "http://localhost:8080"
}
```

- [ ] **Step 4: PowerShell syntax check**

Run:
```bash
cd ~/dotfiles
pwsh -NoProfile -Command "\$null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ./deploy_windows.ps1), [ref]\$null, [ref]\$errs); if (\$errs) { \$errs | ForEach-Object { \$_.Message }; exit 1 } else { 'PARSE OK' }"
```
Expected: `PARSE OK`.

- [ ] **Step 5: Confirm the old whole-dir skills entry is gone and the loop is present**

Run:
```bash
cd ~/dotfiles
grep -c 'Description = "Claude Code skills"' deploy_windows.ps1   # expect 0
grep -c 'per-item, preserving plugin junctions' deploy_windows.ps1 # expect 1
grep -c 'ANTHROPIC_BASE_URL' deploy_windows.ps1                    # expect 1
```
Expected: `0`, `1`, `1`.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add deploy_windows.ps1
git commit -m "feat(deploy-windows): per-item skills symlinks (preserve junctions); set ANTHROPIC_BASE_URL proxy env var"
```

> The secrets bootstrap loop (lines ~581–587) already parses any `export KEY="value"` line from `secrets.env`, so `NINEROUTER_API_KEY` is picked up automatically once present — no script change needed for the secret itself.

---

## Phase C — Migrate this machine

### Task 8: Put the real secret in place

**Files:**
- Modify: `~/.config/dotfiles/secrets.env` (machine-local, gitignored — NOT in the repo)

- [ ] **Step 1: Append the real 9router key to the local secrets file**

The real key was previously hardcoded in the live opencode config (`sk-e13bde9f6291ddc7-lb2bqk-8d6f33d6`). Add it to the gitignored secrets file:

```bash
mkdir -p ~/.config/dotfiles
grep -q 'NINEROUTER_API_KEY' ~/.config/dotfiles/secrets.env 2>/dev/null \
  || echo 'export NINEROUTER_API_KEY="sk-e13bde9f6291ddc7-lb2bqk-8d6f33d6"' >> ~/.config/dotfiles/secrets.env
```

- [ ] **Step 2: Verify it's set and that the file is NOT tracked by git**

Run:
```bash
cd ~/dotfiles
grep -c NINEROUTER_API_KEY ~/.config/dotfiles/secrets.env   # expect >=1
git check-ignore ~/.config/dotfiles/secrets.env 2>/dev/null; echo "(empty above = outside repo, which is correct)"
```
Expected: count ≥ 1. (The secrets file lives outside the repo entirely, so it can never be committed.)

---

### Task 9: Dry-run the deploy

- [ ] **Step 1: Run symlink+env only, in dry-run, as Administrator**

> Symlink creation needs an **elevated** PowerShell. Run this yourself in an Admin pwsh window (type `! ` prefix in the session, or run manually):

```powershell
cd C:\Users\mint\dotfiles
.\deploy_windows.ps1 -DryRun -SkipPackages -SkipFonts
```

- [ ] **Step 2: Review the dry-run output against this checklist**

Confirm the output shows:
- `[DRY RUN] Would create symlink` for agents, commands, opencode.jsonc, settings.json, CLAUDE.md, statusline*.
- Under "Claude Code skills (per-item ...)": `Would create symlink` for each of the 8 gamedev skills (`game-feel`, `game-marketing`, `gamedev-art`, `gamedev-audio`, `indie-production`, `level-design`, `unity-engineering`, `unity-shaders`) and **"already present (left as-is)"** for any name that collides (there should be none — names don't overlap).
- `Would set environment variable` for `ANTHROPIC_BASE_URL`.
- It must **NOT** mention removing `~/.claude/skills` as a directory.

Stop and fix the plan/script if any item is wrong before proceeding.

---

### Task 10: Apply with backups

- [ ] **Step 1: Run for real (Admin pwsh), backups enabled**

```powershell
cd C:\Users\mint\dotfiles
.\deploy_windows.ps1 -SkipPackages -SkipFonts
```
When prompted "backup existing configurations?", answer **Y**. This moves replaced real files/dirs to `*.backup_<timestamp>` (e.g. `~/.claude/agents.backup_…`, `~/.claude/CLAUDE.md.backup_…`, `~/.config/opencode/opencode.jsonc.backup_…`).

- [ ] **Step 2: Reload env so the proxy var is live in new shells**

Open a fresh PowerShell (the `ANTHROPIC_BASE_URL` User env var applies to new processes).

---

### Task 11: Verify the migration

- [ ] **Step 1: Plugin junctions in `~/.claude/skills` survived**

Run:
```bash
powershell.exe -NoProfile -Command "Get-ChildItem \$HOME\.claude\skills -Force | Where-Object { \$_.LinkType -in 'Junction','SymbolicLink' } | Measure-Object | Select-Object -ExpandProperty Count"
```
Expected: ≥ 10 (the caveman/find-skills/skill-creator/… junctions are intact).

- [ ] **Step 2: The 8 gamedev skills are now linked in**

Run:
```bash
for s in game-feel game-marketing gamedev-art gamedev-audio indie-production level-design unity-engineering unity-shaders; do
  test -e ~/.claude/skills/$s && echo "ok: $s" || echo "MISSING: $s"
done
```
Expected: 8 `ok:` lines.

- [ ] **Step 3: Agents + commands unions are present via symlink**

Run:
```bash
ls ~/.claude/agents | wc -l      # expect 10
ls ~/.claude/commands | wc -l    # expect 8
powershell.exe -NoProfile -Command "(Get-Item \$HOME\.claude\agents).LinkType"   # expect SymbolicLink
```
Expected: `10`, `8`, `SymbolicLink`.

- [ ] **Step 4: settings.json is the symlinked portable version, proxy is an env var**

Run:
```bash
powershell.exe -NoProfile -Command "(Get-Item \$HOME\.claude\settings.json).LinkType; [Environment]::GetEnvironmentVariable('ANTHROPIC_BASE_URL','User')"
grep -c ANTHROPIC_BASE_URL ~/.claude/settings.json   # expect 0 (proxy not in file)
```
Expected: `SymbolicLink`, then `http://localhost:8080`, then `0`.

- [ ] **Step 5: opencode loads with the externalized key (no raw secret on disk in repo)**

Run:
```bash
# Secret resolves from env at runtime; confirm the repo/symlinked file has no raw key:
grep -c 'sk-e13b' ~/.config/opencode/opencode.jsonc   # expect 0
grep -c '{env:NINEROUTER_API_KEY}' ~/.config/opencode/opencode.jsonc  # expect 1
```
Expected: `0`, then `1`. If `opencode` CLI is installed, also run `opencode` once and confirm the `9router`/`cursor-acp` providers and models load without an auth error.

- [ ] **Step 6: Claude Code starts through the proxy**

In a fresh shell, launch `claude` and confirm it starts normally (it now reads `ANTHROPIC_BASE_URL` from the env var). If the local proxy on `:8080` is running, requests route through it.

- [ ] **Step 7: Final commit of any plan-tracking docs (if changed) — repo content is already committed in Phase A/B**

```bash
cd ~/dotfiles
git status   # working tree should be clean except your pre-existing unrelated changes
```

---

## Self-Review (completed during authoring)

- **Spec coverage:** agents union (T1), commands union (T2), opencode adopt+sanitize+dedupe (T3), notify hook (T4), settings split/Strategy 1 (T5), CLAUDE.md line (T6), skills per-item + proxy env var in script (T7), secret placement (T8), dry-run/apply/verify with backups (T9–T11), plugin-source default kept (T5). All spec sections map to a task.
- **Placeholder scan:** none — every code/JSON/script step shows full content or exact surgical edits; verification commands include expected output.
- **Name consistency:** `NINEROUTER_API_KEY` (T3 example, T8 secret, T7 note), `claude-notify.sh` (T4, T5), `unity-project-detect.sh` (verified to exist), skill names consistent across T9/T11.

## Open (non-blocking) flags from the spec
- §3 plugin/marketplace source: kept live's `claude-plugins-official` (Task 5). Change in T5 Step 1 if standardizing on the `obra/superpowers-marketplace` source instead.
- §5 deprecated-API line: included (Task 6). Skip Task 6 if not wanted.

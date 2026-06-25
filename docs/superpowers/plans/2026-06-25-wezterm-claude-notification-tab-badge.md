# WezTerm Claude Notification Tab Badge — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop Claude Code notifications from auto-switching the WezTerm tab on Windows, and instead flag the originating tab with a non-switching, Catppuccin-Frappe bell badge that clears on visit.

**Architecture:** Two halves. (1) The *fix*: vendor the machine-local `claude-notify.ps1` into the repo with its `wezterm cli activate-pane` focus-steal removed, and de-hardcode its path in `notify-lib.sh`. (2) The *badge*: `notify-lib.sh` emits a WezTerm `SetUserVar` OSC on the pane's tty; `wezterm.lua` catches `user-var-changed` into `wezterm.GLOBAL`; a custom tabline component renders a per-state coloured bell, falling back to native `has_unseen_output` when no precise signal is present, and clearing on visit.

**Tech Stack:** Bash (Git Bash hooks), PowerShell (BurntToast), Lua 5.4 (WezTerm config + tabline.wez plugin), the existing bash test harness in `claude/hooks/tests/`.

## Global Constraints

- **Platform:** Feature is Windows-only. All `notify-lib.sh` changes live in the `MINGW*|MSYS*|CYGWIN*|Windows_NT` case; all `wezterm.lua` changes live inside the existing `if is_windows then ... end` block (the only place `tabline.setup` is called).
- **Palette (exact hex, Catppuccin Frappe):** crust `#232634`, peach `#ef9f76`, yellow `#e5c890`, overlay0 `#838ba7`.
- **Glyphs (nerdfont names, authoritative):** needs-you = `md_bell_ring`; finished = `md_bell`; background fallback = `md_bell_outline`.
- **User-var contract:** name `claude_status`; values `notification` (needs you) and `stop` (finished); empty string clears. OSC form: `\033]1337;SetUserVar=claude_status=<base64(value)>\007`.
- **`wezterm.GLOBAL` is a serialization proxy** — never mutate nested tables in place; read the sub-table, mutate, reassign the whole key (matches existing discipline at `wezterm.lua:316-321`).
- **Keep the BurntToast desktop toast.** Only the focus-steal is removed.
- **Graceful degradation:** the precise badge depends on the OSC reaching WezTerm; the `has_unseen_output` fallback must work with zero signalling.
- **Commits:** Conventional-commit style. **No** `Co-Authored-By` / AI-attribution trailers (repo owner's rule).
- **Run the hook tests with:** `bash claude/hooks/tests/run-tests.sh`.
- **No deploy changes:** `.config/wezterm` and `claude/hooks` are directory symlinks, so new files inside them are live without re-running `deploy_windows.ps1`.

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `claude/hooks/bin/claude-notify.ps1` | BurntToast desktop toast only — no pane focus | **Create** (vendored, cleaned) |
| `claude/hooks/lib/notify-lib.sh` | Resolve notifier relative to itself; emit `claude_status` OSC on Windows | **Modify** (Windows branch only) |
| `.config/wezterm/tabline_claude_badge.lua` | Pure render logic: precedence (precise > unseen-output > none) + clear-on-visit | **Create** |
| `.config/wezterm/wezterm.lua` | Catch `user-var-changed` → GLOBAL; preload component; add `"claude"` to tab sections | **Modify** (inside `is_windows`) |
| `claude/hooks/tests/test-notify-windows.sh` | Asserts the fix (no `activate-pane`, no `C:\Tools`) + the OSC emit | **Create** |
| `claude/hooks/tests/test-tabline-claude-badge.sh` | Bash wrapper that runs the Lua unit test | **Create** |
| `claude/hooks/tests/test-tabline-claude-badge.lua` | Lua unit test for the component (stubbed `wezterm`) | **Create** |

---

## Task 1: Vendor the notifier and stop the auto-switch

**Files:**
- Create: `claude/hooks/bin/claude-notify.ps1`
- Create: `claude/hooks/tests/test-notify-windows.sh`
- Modify: `claude/hooks/lib/notify-lib.sh` (the `MINGW*|MSYS*|CYGWIN*|Windows_NT)` case, currently lines 76-82)

**Interfaces:**
- Produces: a vendored notifier at `claude/hooks/bin/claude-notify.ps1` accepting `-Title <string> -Message <string>` (no `-PaneId`).
- Produces: `notify-lib.sh` resolves the notifier via `"$(dirname "${BASH_SOURCE[0]}")/../bin/claude-notify.ps1"` and `cygpath -w`, with no `C:\Tools` literal.

- [ ] **Step 1: Write the failing test**

Create `claude/hooks/tests/test-notify-windows.sh`:

```bash
#!/usr/bin/env bash
# Windows-branch behaviour of notify-lib.sh: the fix (no focus-steal, no hardcoded
# path) and the badge OSC emit. Hermetic: stubs uname/powershell.exe, captures the
# OSC via CC_TTY.
. "$(dirname "$0")/_harness.sh"

LIB="$(dirname "$0")/../lib/notify-lib.sh"
PS1="$(dirname "$0")/../bin/claude-notify.ps1"

# --- Part 1 fix: vendored notifier exists and never focuses a pane ---
test -f "$PS1"; assert_exit "$?" "0" "vendored claude-notify.ps1 exists in repo"
grep -qi 'activate-pane' "$PS1"; assert_exit "$?" "1" "vendored notifier contains no activate-pane"
grep -qiE 'c:\\\\tools|/c/tools' "$LIB"; assert_exit "$?" "1" "notify-lib.sh has no hardcoded C:\\Tools path"
grep -q 'BASH_SOURCE' "$LIB"; assert_exit "$?" "0" "notify-lib.sh resolves notifier relative to itself"

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-notify-windows.sh`
Expected: FAIL — `vendored claude-notify.ps1 exists` fails (file not created yet), and the `C:\Tools` grep still finds the literal in `notify-lib.sh`.

- [ ] **Step 3: Create the vendored, cleaned notifier**

Create `claude/hooks/bin/claude-notify.ps1`:

```powershell
param(
    [string]$Title = "Claude Code",
    [string]$Message = "Notification"
)

# Desktop toast only. This script deliberately does NOT focus any WezTerm pane:
# the tab-attention cue is a non-switching bell badge driven by a SetUserVar OSC
# from notify-lib.sh (see .config/wezterm/tabline_claude_badge.lua).
Import-Module BurntToast -ErrorAction SilentlyContinue
New-BurntToastNotification -Text $Title, $Message
```

- [ ] **Step 4: De-hardcode the notifier path in `notify-lib.sh`**

Replace the Windows case (currently lines 76-82):

```bash
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      local notifier="/c/Tools/claude-notify.ps1"
      if [ -f "$notifier" ]; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\\Tools\\claude-notify.ps1" \
          -Title "$title" -Message "$body" -PaneId "${WEZTERM_PANE:-}"
      fi
      ;;
```

with:

```bash
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      # Desktop toast via the repo-vendored notifier (resolved relative to this lib,
      # so it rides the claude/ -> ~/.claude symlink; no machine-local C:\Tools file).
      local notifier_sh; notifier_sh="$(dirname "${BASH_SOURCE[0]}")/../bin/claude-notify.ps1"
      if [ -f "$notifier_sh" ]; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$notifier_sh")" \
          -Title "$title" -Message "$body"
      fi
      ;;
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-notify-windows.sh`
Expected: PASS — all four assertions, `--- 4 run, 0 failed ---`.

- [ ] **Step 6: Run the full hook suite (no regressions)**

Run: `bash claude/hooks/tests/run-tests.sh`
Expected: `test-notify-windows.sh` passes. (Pre-existing macOS-specific assertions in `test-cc-notify-pending.sh` may behave as before — do not "fix" them in this task.)

- [ ] **Step 7: Commit**

```bash
git add claude/hooks/bin/claude-notify.ps1 claude/hooks/lib/notify-lib.sh claude/hooks/tests/test-notify-windows.sh
git commit -m "fix(windows): stop Claude notifier auto-switching the WezTerm tab"
```

---

## Task 2: Emit the `claude_status` user-var OSC

**Files:**
- Modify: `claude/hooks/lib/notify-lib.sh` (same Windows case)
- Modify: `claude/hooks/tests/test-notify-windows.sh` (add OSC assertions)

**Interfaces:**
- Consumes: `kind` local in `cc_notify` (`"notification"` | `"stop"`, default `notification`).
- Produces: on Windows, writes `\033]1337;SetUserVar=claude_status=<base64(kind)>\007` to `${CC_TTY:-/dev/tty}`. The `CC_TTY` override exists for tests; production uses `/dev/tty`.

- [ ] **Step 1: Add the failing OSC assertions to the test**

In `claude/hooks/tests/test-notify-windows.sh`, insert before the final `finish` line:

```bash
# --- Part 2 badge: Windows branch emits the claude_status user-var OSC ---
STUB="$(mktemp -d)"
cat > "$STUB/uname" <<'EOF'
#!/usr/bin/env bash
echo "MINGW64_NT-10.0-26200"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/powershell.exe"
chmod +x "$STUB"/*
export PATH="$STUB:$PATH"

export CC_TTY="$(mktemp)"
unset TMUX TMUX_PANE            # exercise only the Windows toast/OSC path
. "$LIB"

cc_notify "Claude Code" "needs you" notification
# base64("notification") = bm90aWZpY2F0aW9u
assert_contains "$(cat "$CC_TTY")" "SetUserVar=claude_status=bm90aWZpY2F0aW9u" "emits base64('notification') OSC"

: > "$CC_TTY"
cc_notify "Claude Code" "done" stop
# base64("stop") = c3RvcA==
assert_contains "$(cat "$CC_TTY")" "SetUserVar=claude_status=c3RvcA==" "emits base64('stop') OSC"

: > "$CC_TTY"
cc_notify "Claude Code" "hi"   # kind omitted -> defaults to notification
assert_contains "$(cat "$CC_TTY")" "SetUserVar=claude_status=bm90aWZpY2F0aW9u" "kind defaults to notification in OSC"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-notify-windows.sh`
Expected: FAIL — the three new `SetUserVar=claude_status=...` assertions fail because nothing is written to `CC_TTY` yet.

- [ ] **Step 3: Add the OSC emit to the Windows branch**

In `notify-lib.sh`, inside the `MINGW*|MSYS*|CYGWIN*|Windows_NT)` case, add the OSC emit **above** the `notifier_sh` block:

```bash
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      # Tab-badge cue: set the claude_status WezTerm user var on this pane's terminal
      # so the tab bar can flag which tab is waiting, without switching to it (see
      # .config/wezterm/tabline_claude_badge.lua). Invisible OSC; CC_TTY is a test seam.
      printf '\033]1337;SetUserVar=claude_status=%s\007' \
        "$(printf '%s' "$kind" | base64 | tr -d '\n')" > "${CC_TTY:-/dev/tty}" 2>/dev/null || true
      # Desktop toast via the repo-vendored notifier (resolved relative to this lib,
      # so it rides the claude/ -> ~/.claude symlink; no machine-local C:\Tools file).
      local notifier_sh; notifier_sh="$(dirname "${BASH_SOURCE[0]}")/../bin/claude-notify.ps1"
      if [ -f "$notifier_sh" ]; then
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$notifier_sh")" \
          -Title "$title" -Message "$body"
      fi
      ;;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-notify-windows.sh`
Expected: PASS — `--- 7 run, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add claude/hooks/lib/notify-lib.sh claude/hooks/tests/test-notify-windows.sh
git commit -m "feat(windows): emit claude_status user-var OSC for the WezTerm tab badge"
```

---

## Task 3: The tabline badge component (render logic)

**Files:**
- Create: `.config/wezterm/tabline_claude_badge.lua`
- Create: `claude/hooks/tests/test-tabline-claude-badge.lua`
- Create: `claude/hooks/tests/test-tabline-claude-badge.sh`

**Interfaces:**
- Consumes: `wezterm.GLOBAL.claude_alert` — a table mapping `tostring(pane_id)` → `"notification"`|`"stop"` (produced by Task 4's handler), and `tab.panes[].pane_id` / `tab.panes[].has_unseen_output` / `tab.is_active` (tabline.wez's `TabInformation`).
- Produces: a module table `{ default_opts = {}, update = function(tab, opts) ... end }` whose `update` returns a one-space string (badge shown) or `nil` (no badge), and sets `opts.icon = { <glyph>, color = { fg, bg } }`. Registered by Task 4 under the component name `claude`.

- [ ] **Step 1: Write the failing Lua unit test**

Create `claude/hooks/tests/test-tabline-claude-badge.lua`:

```lua
-- Unit test for tabline_claude_badge.lua. Stubs `wezterm`, exercises update().
-- arg[1] = absolute path to the module under test.
local module_path = arg[1]
local PASS, FAIL = 0, 0
local function ok(cond, msg)
  if cond then PASS = PASS + 1; print("  PASS: " .. msg)
  else FAIL = FAIL + 1; print("  FAIL: " .. msg) end
end

local stub = {
  nerdfonts = { md_bell_ring = "RING", md_bell = "BELL", md_bell_outline = "OUT" },
  GLOBAL = {},
  time = { now = function() return { format = function() return "00" end } end },
}
package.loaded.wezterm = stub

local badge = dofile(module_path)

local function tab(is_active, panes) return { is_active = is_active, panes = panes } end
local function pane(id, unseen) return { pane_id = id, has_unseen_output = unseen or false } end

-- 1. precise notification -> ring glyph + peach bg
stub.GLOBAL.claude_alert = { ["5"] = "notification" }
local opts = {}
local r = badge.update(tab(false, { pane(5) }), opts)
ok(r == ' ', "notification renders a badge")
ok(opts.icon and opts.icon[1] == "RING", "notification uses md_bell_ring")
ok(opts.icon.color.bg == "#ef9f76", "notification badge bg is peach")

-- 2. precise stop -> bell glyph + yellow bg
stub.GLOBAL.claude_alert = { ["5"] = "stop" }
opts = {}
badge.update(tab(false, { pane(5) }), opts)
ok(opts.icon[1] == "BELL", "stop uses md_bell")
ok(opts.icon.color.bg == "#e5c890", "stop badge bg is yellow")

-- 3. no alert + unseen output -> outline fallback
stub.GLOBAL.claude_alert = {}
opts = {}
badge.update(tab(false, { pane(9, true) }), opts)
ok(opts.icon[1] == "OUT", "unseen output uses md_bell_outline fallback")

-- 4. no alert + no output -> no badge
opts = {}
r = badge.update(tab(false, { pane(9, false) }), opts)
ok(r == nil, "no alert and no output renders nothing")

-- 5. active tab clears its alert and renders nothing (clear-on-visit)
stub.GLOBAL.claude_alert = { ["5"] = "notification" }
opts = {}
r = badge.update(tab(true, { pane(5) }), opts)
ok(r == nil, "active tab renders no badge")
ok(stub.GLOBAL.claude_alert["5"] == nil, "active tab clears its pane's alert")

print(string.format("--- %d passed, %d failed ---", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
```

Create the bash wrapper `claude/hooks/tests/test-tabline-claude-badge.sh`:

```bash
#!/usr/bin/env bash
# Runs the Lua unit test for the WezTerm Claude badge component.
. "$(dirname "$0")/_harness.sh"

if ! command -v lua >/dev/null 2>&1; then
  echo "  SKIP: lua not installed (badge component unit test)"
  finish; exit 0
fi

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"   # tests -> hooks -> claude -> repo root
module="$repo_root/.config/wezterm/tabline_claude_badge.lua"
lua "$(dirname "$0")/test-tabline-claude-badge.lua" "$module"
assert_exit "$?" "0" "tabline_claude_badge.lua unit tests pass"
finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-tabline-claude-badge.sh`
Expected: FAIL — `dofile` cannot open the not-yet-created module, the Lua process exits non-zero, and `assert_exit` reports `tabline_claude_badge.lua unit tests pass (exit expected '0', got '1')`.

- [ ] **Step 3: Create the component module**

Create `.config/wezterm/tabline_claude_badge.lua`:

```lua
local wezterm = require('wezterm')

-- Catppuccin Frappe tokens (kept local so the badge stays on-theme with the rest of
-- the config; change here if the flavour ever changes).
local frappe = {
  crust    = '#232634',
  peach    = '#ef9f76',
  yellow   = '#e5c890',
  overlay0 = '#838ba7',
}

-- Off by default: tmux parity is static, and flashing costs periodic repaints. When
-- true, the urgent "needs you" badge alternates shade once a second (requires a low
-- config.status_update_interval to repaint; see wezterm.lua).
local FLASH = false

return {
  default_opts = {},
  update = function(tab, opts)
    local alerts = wezterm.GLOBAL.claude_alert or {}

    -- Clear-on-visit: visiting the tab dismisses its precise alert. Reassign GLOBAL
    -- (nested writes on the serialization proxy don't persist).
    if tab.is_active then
      local changed = false
      for _, p in ipairs(tab.panes) do
        local k = tostring(p.pane_id)
        if alerts[k] ~= nil then alerts[k] = nil; changed = true end
      end
      if changed then wezterm.GLOBAL.claude_alert = alerts end
      return
    end

    -- Precise tier: any pane in this tab carries a claude_status alert.
    local kind
    for _, p in ipairs(tab.panes) do
      kind = kind or alerts[tostring(p.pane_id)]
    end
    if kind == 'notification' then
      local bg = frappe.peach
      if FLASH and (tonumber(wezterm.time.now():format('%S')) or 0) % 2 == 1 then
        bg = frappe.yellow
      end
      opts.icon = { wezterm.nerdfonts.md_bell_ring, color = { fg = frappe.crust, bg = bg } }
      return ' '
    elseif kind == 'stop' then
      opts.icon = { wezterm.nerdfonts.md_bell, color = { fg = frappe.crust, bg = frappe.yellow } }
      return ' '
    end

    -- Fallback tier: native unseen output, needs no external signal.
    for _, p in ipairs(tab.panes) do
      if p.has_unseen_output then
        opts.icon = { wezterm.nerdfonts.md_bell_outline, color = { fg = frappe.overlay0 } }
        return ' '
      end
    end
  end,
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-tabline-claude-badge.sh`
Expected: PASS — Lua prints `--- 10 passed, 0 failed ---` and the wrapper reports `--- 1 run, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add .config/wezterm/tabline_claude_badge.lua claude/hooks/tests/test-tabline-claude-badge.lua claude/hooks/tests/test-tabline-claude-badge.sh
git commit -m "feat(wezterm): Claude notification bell tab-badge component"
```

---

## Task 4: Wire the component into `wezterm.lua`

**Files:**
- Modify: `.config/wezterm/wezterm.lua` (inside `if is_windows then ... end`): add the `user-var-changed` handler; preload the component; add `"claude"` to `tab_active`/`tab_inactive`.

**Interfaces:**
- Consumes: the module from Task 3 (`require('tabline_claude_badge')`); the `claude_status` OSC from Task 2.
- Produces: `wezterm.GLOBAL.claude_alert[tostring(pane_id)] = kind`, read by the component.

- [ ] **Step 1: Add the `user-var-changed` handler**

In `.config/wezterm/wezterm.lua`, inside the `if is_windows then` block, immediately after the existing `wezterm.on("update-status", ...)` handler (it ends at line 323 with `end)`), add:

```lua
    -- Claude notification badge: record which pane is waiting on you so the tabline
    -- component can flag its tab without switching to it. notify-lib.sh sets the
    -- claude_status user var via OSC (value "notification" | "stop"; "" clears).
    -- GLOBAL is a serialization proxy, so read-mutate-reassign the whole sub-table.
    wezterm.on("user-var-changed", function(_, pane, name, value)
        if name ~= "claude_status" then
            return
        end
        local t = wezterm.GLOBAL.claude_alert or {}
        t[tostring(pane:pane_id())] = (value ~= "" and value) or nil
        wezterm.GLOBAL.claude_alert = t
    end)
```

- [ ] **Step 2: Preload the component under tabline's expected name**

Still inside `if is_windows`, immediately **before** the `tabline.setup({` call (line 434), add:

```lua
    -- Register our custom tab component under the name tabline.wez will require()
    -- for it. require() checks package.loaded first, so this avoids depending on
    -- nested path resolution into the plugin's namespace.
    package.loaded['tabline.components.tab.claude'] = require('tabline_claude_badge')
```

- [ ] **Step 3: Add `"claude"` to the tab sections**

In the `tabline.setup({ ... sections = { ... } })` block, replace the `tab_inactive` definition (lines 504-508) with the version below. **Leave `tab_active` unchanged** — the active tab must not show a badge, and clear-on-visit still works because tabline's `create_tab_content` (tabs.lua:45-46) computes the `tab_inactive` components for *every* tab, so the component's `is_active` clear branch runs for the focused tab through this entry alone.

```lua
            tab_inactive = {
                "index",
                "claude", -- Claude bell badge: precise alert, else unseen-output fallback;
                          -- also runs clear-on-visit for the active tab (see note above)
                { "tab", padding = { left = 0, right = 1 } },
            },
```

- [ ] **Step 4: Syntax-check the edited config**

Run: `lua -e "assert(loadfile(arg[1]))" .config/wezterm/wezterm.lua && echo "PARSE OK"`
Expected: `PARSE OK` (no syntax error). (This parses without executing, so the WezTerm/plugin requires are not run.)

- [ ] **Step 5: Re-run the full hook + component suite (no regressions)**

Run: `bash claude/hooks/tests/run-tests.sh`
Expected: `test-notify-windows.sh` and `test-tabline-claude-badge.sh` both pass.

- [ ] **Step 6: Commit**

```bash
git add .config/wezterm/wezterm.lua
git commit -m "feat(wezterm): wire Claude tab badge into tabline + user-var handler"
```

---

## Task 5: Integration & manual acceptance (Windows + WezTerm GUI)

**Files:** none changed (verification only). This task cannot be automated — it confirms the OSC traverses Claude's fullscreen TUI to WezTerm (spec risk #1) and the end-to-end behaviour.

**Interfaces:**
- Consumes: everything from Tasks 1-4, live in WezTerm via the existing directory symlinks.

- [ ] **Step 1: Reload WezTerm config**

In WezTerm: press `Ctrl+Shift+R` (or restart WezTerm). Expected: no config-error toast.

- [ ] **Step 2: Confirm OSC reachability (the key risk)**

Temporarily add a log line inside the `user-var-changed` handler (first line of the function body):

```lua
        wezterm.log_info("claude_status user-var: " .. tostring(name) .. "=" .. tostring(value))
```

Reload config. From a **different** WezTerm tab than the one you watch, run in a pane:

```bash
printf '\033]1337;SetUserVar=claude_status=%s\007' "$(printf stop | base64)" > /dev/tty
```

Open the debug overlay (leader `Ctrl+Space` then `:` → it runs `ShowDebugOverlay`, see `wezterm.lua:422`). Expected: a log line `claude_status user-var: claude_status=stop`.
- If present → reachability confirmed; **remove the temporary `wezterm.log_info` line** and reload.
- If absent → the precise tier won't fire through Claude's TUI; the `has_unseen_output` fallback still works. Record the finding and stop here (precise tier becomes a future follow-up); remove the temp log line.

- [ ] **Step 3: End-to-end with real Claude notifications**

From a different tab than Claude's:
- Trigger a permission prompt (run a command Claude must ask about). Expected: **no tab switch**; Claude's tab shows a **peach** `md_bell_ring` badge; a BurntToast toast appears.
- Let a turn finish. Expected: **no tab switch**; the badge on Claude's tab is **yellow** `md_bell`.
- Switch to Claude's tab. Expected: the badge **clears** on visit.

- [ ] **Step 4: Confirm the fallback tier**

With no precise alert outstanding, produce background output in another tab (e.g. a long `ls`-like command) and tab away. Expected: a **dim** `md_bell_outline` badge appears and clears when you visit the tab.

- [ ] **Step 5: Record the outcome**

If Step 2 failed (OSC not reaching WezTerm), note it in the spec's "Risks" section and treat the precise tier as deferred. No commit if only the temporary log line was added and removed; otherwise nothing to commit.

---

## Self-Review

**Spec coverage:**
- Part 1 (remove auto-switch, vendor PS1, de-hardcode) → Task 1. ✓
- Part 2a (OSC emit) → Task 2. ✓
- Part 2b (`user-var-changed` → GLOBAL) → Task 4 Step 1. ✓
- Part 2c (custom component, `package.loaded` preload, tab sections) → Task 3 + Task 4 Steps 2-3. ✓
- Part 2d (clear-on-visit) → Task 3 (component `is_active` branch) + Task 4 (component runs for all tabs). ✓
- Visual treatment (glyphs/colours, flash off) → Task 3 module + Global Constraints. ✓
- Testing: hook tests (OSC + activate-pane guard) → Tasks 1-2; component unit test → Task 3; OSC reachability + manual acceptance → Task 5. ✓
- Graceful degradation → fallback tier in Task 3, verified in Task 5 Step 4. ✓
- Keep toast → Task 1 notifier retains `New-BurntToastNotification`. ✓
- No deploy changes → Global Constraints (directory symlinks). ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code; no "similar to" references. ✓

**Type/name consistency:** user-var name `claude_status` and values `notification`/`stop` consistent across Tasks 2/4/3; GLOBAL key `claude_alert` keyed by `tostring(pane_id)` consistent between Task 4 (writer) and Task 3 (reader); component name `claude` consistent between Task 4 preload and tab sections; glyph names (`md_bell_ring`/`md_bell`/`md_bell_outline`) consistent between Task 3 and Global Constraints. ✓

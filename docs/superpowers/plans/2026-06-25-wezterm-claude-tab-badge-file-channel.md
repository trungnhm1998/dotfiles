# WezTerm Claude Tab Badge — File-Channel Signal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the non-switching WezTerm tab badge reliably flag which Claude tab needs you on Windows, by replacing the OSC-over-tty signal with a `$WEZTERM_PANE`-keyed file the WezTerm poller reads, and removing the noisy `has_unseen_output` fallback.

**Architecture:** One producer (the notify hook writes `…/wezterm-alerts/<pane_id>` = `notification`|`stop`), one reconciler (WezTerm's existing `update-status` handler turns that directory into `GLOBAL.claude_alert`, the sole writer of that table), one renderer (the tabline component reads `GLOBAL.claude_alert` and nothing else). The reconcile logic is extracted into a pure, unit-tested Lua module so the risky part is no longer GUI-only.

**Tech Stack:** Bash (Git Bash/MSYS hook), Lua 5.4 (WezTerm config + embedded runtime), the `tabline.wez` plugin, BurntToast (unchanged).

**Spec:** `docs/superpowers/specs/2026-06-25-wezterm-claude-tab-badge-file-channel-design.md`

## Global Constraints

- **Platform scope:** every change lives inside the Windows paths only — the `MINGW*|MSYS*|CYGWIN*|Windows_NT)` branch of `notify-lib.sh` and the `if is_windows then` block of `wezterm.lua`. Do not touch the macOS/Linux/tmux code paths.
- **The contract (verbatim):** alert file path is `${XDG_CACHE_HOME:-$HOME/.cache}/claude-notify/wezterm-alerts/<pane_id>`; the file body is exactly `notification` or `stop` (written with `printf '%s'`, no trailing newline). The WezTerm side derives the same dir from `wezterm.home_dir` + `XDG_CACHE_HOME`.
- **Colors (verbatim, Catppuccin Frappe):** `notification` → glyph `md_bell_ring`, bg peach `#ef9f76`; `stop` → glyph `md_bell`, bg yellow `#e5c890`; both fg crust `#232634`.
- **Single writer:** after this change, the `update-status` poller is the *only* writer of `wezterm.GLOBAL.claude_alert`. The component reads it; it must not mutate it. The `user-var-changed` handler is removed.
- **Shared branch discipline:** branch `feat/zellij-windows` is worked by a concurrent session. Commit with **explicit pathspecs only** — `git add -- <paths>` and `git commit -m "<msg>" -- <paths>`. Never `git add -A` / `git add .`. No history rewrites.
- **Commit hygiene:** conventional-commit messages; **no** `Co-Authored-By` or AI-attribution trailers.
- **Test runner caveat:** run each task's *specific* test file. Do **not** gate on `run-tests.sh` (the whole suite) — `test-cc-notify-pending.sh` carries pre-existing macOS-only assertions that fail on Windows and are out of scope here.
- **Toolchain present:** `lua` 5.4.8, `luac`, `base64`, `cygpath`, `mktemp` are installed, so all Lua and Bash tests are real gates (none should SKIP on this machine).
- **TDD:** write the test, run it and watch it fail for the stated reason, implement the minimal change, run it and watch it pass, commit.

---

## File Structure

| File | Responsibility | Task |
|------|----------------|------|
| `.config/wezterm/wezterm_claude_alerts.lua` (NEW) | Pure reconcile logic: `dir()` + `reconcile()`. No `wezterm` require; all I/O injected. | 1 |
| `claude/hooks/tests/test-claude-alerts.lua` (NEW) | Lua unit test for the module. | 1 |
| `claude/hooks/tests/test-claude-alerts.sh` (NEW) | Bash wrapper that runs the Lua test (auto-discovered by `run-tests.sh`). | 1 |
| `claude/hooks/lib/notify-lib.sh` (MODIFY) | Windows branch: replace OSC-to-tty with `$WEZTERM_PANE`-keyed file write. | 2 |
| `claude/hooks/tests/test-notify-windows.sh` (REWRITE) | Assert the file write + the OSC channel is gone + toast still fires. | 2 |
| `.config/wezterm/tabline_claude_badge.lua` (REWRITE) | Pure reader of `GLOBAL.claude_alert`; no fallback, no FLASH. | 3 |
| `claude/hooks/tests/test-tabline-claude-badge.lua` (MODIFY) | Drop the fallback case; assert the component no longer mutates GLOBAL. | 3 |
| `.config/wezterm/wezterm.lua` (MODIFY) | Require the module, reconcile in `update-status`, remove `user-var-changed`. | 4 |
| `claude/hooks/tests/test-wezterm-wiring.sh` (NEW) | Static + `loadfile` parse gate for the wiring. | 4 |

---

### Task 1: Reconcile module (pure Lua) + unit test

**Files:**
- Create: `.config/wezterm/wezterm_claude_alerts.lua`
- Create (test): `claude/hooks/tests/test-claude-alerts.lua`
- Create (wrapper): `claude/hooks/tests/test-claude-alerts.sh`

**Interfaces:**
- Consumes: nothing (leaf module).
- Produces (consumed by Task 4):
  - `M.dir(home, xdg_cache) -> string` — returns `(xdg_cache or home.."/.cache").."/claude-notify/wezterm-alerts"`.
  - `M.reconcile(paths, live, visited, read_file, remove) -> table` — `paths` is an array of absolute file paths; `live` and `visited` are sets keyed by pane-id string → `true`; `read_file(path) -> string|nil`; `remove(path)`. Returns `{ [pane_id_string] = kind }`, having called `remove` on every path whose pane id is not in `live` or is in `visited`.

- [ ] **Step 1: Write the failing test (Lua)**

Create `claude/hooks/tests/test-claude-alerts.lua`:

```lua
-- Unit test for wezterm_claude_alerts.lua (pure reconcile + dir helpers).
-- arg[1] = absolute path to the module under test.
local module_path = arg[1]
local PASS, FAIL = 0, 0
local function ok(cond, msg)
  if cond then PASS = PASS + 1; print("  PASS: " .. msg)
  else FAIL = FAIL + 1; print("  FAIL: " .. msg) end
end

local M = dofile(module_path)

-- dir(): honours XDG_CACHE_HOME, else home/.cache
ok(M.dir("/home/me", nil) == "/home/me/.cache/claude-notify/wezterm-alerts",
  "dir() defaults to home/.cache")
ok(M.dir("/home/me", "/xdg") == "/xdg/claude-notify/wezterm-alerts",
  "dir() honours XDG_CACHE_HOME")

-- reconcile(): live+unvisited keeps alert; visited removed; dead removed
local removed = {}
local function remove(p) removed[p] = true end
local bodies = { ["/d/10"] = "notification", ["/d/11"] = "stop", ["/d/99"] = "stop" }
local function read_file(p) return bodies[p] end
local paths   = { "/d/10", "/d/11", "/d/99" }
local live    = { ["10"] = true, ["11"] = true }   -- 99 is dead
local visited = { ["11"] = true }                  -- 11 is the active tab
local alerts  = M.reconcile(paths, live, visited, read_file, remove)

ok(alerts["10"] == "notification", "live unvisited pane keeps its alert")
ok(alerts["11"] == nil, "visited pane's alert is dropped")
ok(alerts["99"] == nil, "dead pane's alert is dropped")
ok(removed["/d/11"] == true, "visited pane's file is removed")
ok(removed["/d/99"] == true, "dead pane's file is removed")
ok(removed["/d/10"] == nil, "live unvisited pane's file is kept")

-- reconcile(): trailing whitespace trimmed; empty body -> no entry
local bodies2 = { ["/d/7"] = "notification\n", ["/d/8"] = "" }
local alerts2 = M.reconcile({ "/d/7", "/d/8" }, { ["7"] = true, ["8"] = true }, {},
  function(p) return bodies2[p] end, function() end)
ok(alerts2["7"] == "notification", "trailing newline is trimmed from kind")
ok(alerts2["8"] == nil, "empty body yields no entry")

print(string.format("--- %d passed, %d failed ---", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
```

Create the wrapper `claude/hooks/tests/test-claude-alerts.sh`:

```bash
#!/usr/bin/env bash
# Runs the Lua unit test for the WezTerm Claude alert reconcile module.
. "$(dirname "$0")/_harness.sh"

if ! command -v lua >/dev/null 2>&1; then
  echo "  SKIP: lua not installed (claude-alerts reconcile unit test)"
  finish; exit 0
fi

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"   # tests -> hooks -> claude -> repo root
module="$repo_root/.config/wezterm/wezterm_claude_alerts.lua"
lua "$(dirname "$0")/test-claude-alerts.lua" "$module"
assert_exit "$?" "0" "wezterm_claude_alerts.lua unit tests pass"
finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-claude-alerts.sh`
Expected: FAIL — `lua` errors with `cannot open …/wezterm_claude_alerts.lua` (module does not exist yet); the wrapper reports `FAIL: wezterm_claude_alerts.lua unit tests pass (exit expected '0', got '1')` and `finish` exits non-zero.

- [ ] **Step 3: Write the module**

Create `.config/wezterm/wezterm_claude_alerts.lua`:

```lua
-- Pure reconcile logic for the Claude tab-badge alert directory. Extracted from
-- wezterm.lua so it can be unit-tested without loading the full WezTerm config.
-- No `require('wezterm')`: all I/O is injected by the caller.
local M = {}

-- Shared directory contract with claude/hooks/lib/notify-lib.sh.
function M.dir(home, xdg_cache)
  return (xdg_cache or (home .. '/.cache')) .. '/claude-notify/wezterm-alerts'
end

-- paths:    array of absolute file paths (e.g. from wezterm.read_dir)
-- live:     set of currently-live pane-id strings  -> true
-- visited:  set of pane-id strings in the active tab -> true
-- read_file(path) -> string|nil   remove(path) -> ()
-- Returns { [pane_id] = kind }; removes stale (dead pane) and visited files.
function M.reconcile(paths, live, visited, read_file, remove)
  local alerts = {}
  for _, path in ipairs(paths) do
    local id = path:match('([^/\\]+)$')
    if id then
      if not live[id] or visited[id] then
        remove(path)
      else
        local kind = read_file(path)
        if kind then kind = kind:gsub('%s+$', '') end
        if kind and kind ~= '' then alerts[id] = kind end
      end
    end
  end
  return alerts
end

return M
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-claude-alerts.sh`
Expected: PASS — all `PASS:` lines, ending `--- 10 passed, 0 failed ---` then `PASS: wezterm_claude_alerts.lua unit tests pass` and `--- 1 run, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add -- .config/wezterm/wezterm_claude_alerts.lua claude/hooks/tests/test-claude-alerts.lua claude/hooks/tests/test-claude-alerts.sh
git commit -m "feat(wezterm): add pane-keyed Claude alert reconcile module" -- .config/wezterm/wezterm_claude_alerts.lua claude/hooks/tests/test-claude-alerts.lua claude/hooks/tests/test-claude-alerts.sh
```

---

### Task 2: Producer — pane-keyed file write in notify-lib.sh

**Files:**
- Modify: `claude/hooks/lib/notify-lib.sh` (the `MINGW*|MSYS*|CYGWIN*|Windows_NT)` branch — currently lines 76-89; the OSC emit to replace is lines 77-81)
- Rewrite (test): `claude/hooks/tests/test-notify-windows.sh`

**Interfaces:**
- Consumes: the directory contract (Global Constraints) — must match `M.dir` from Task 1.
- Produces (runtime artifact, read by Task 4): a file `<alert_dir>/<$WEZTERM_PANE>` whose body is `$kind`.

- [ ] **Step 1: Rewrite the test first**

Replace the entire contents of `claude/hooks/tests/test-notify-windows.sh` with:

```bash
#!/usr/bin/env bash
# Windows-branch behaviour of notify-lib.sh: the notifier fix (no focus-steal, no
# hardcoded path) and the pane-keyed tab-badge file write. Hermetic: stubs
# uname/powershell.exe/cygpath; writes alerts into a temp CC_ALERT_DIR.
. "$(dirname "$0")/_harness.sh"

LIB="$(dirname "$0")/../lib/notify-lib.sh"
PS1="$(dirname "$0")/../bin/claude-notify.ps1"

# --- Part 1: vendored notifier exists and never focuses a pane ---
test -f "$PS1"; assert_exit "$?" "0" "vendored claude-notify.ps1 exists in repo"
grep -qi 'activate-pane' "$PS1"; assert_exit "$?" "1" "vendored notifier contains no activate-pane"
grep -qiE 'c:\\\\tools|/c/tools' "$LIB"; assert_exit "$?" "1" "notify-lib.sh has no hardcoded C:\\Tools path"
grep -q 'BASH_SOURCE' "$LIB"; assert_exit "$?" "0" "notify-lib.sh resolves notifier relative to itself"

# --- Part 2: the OSC/tty channel is gone, replaced by the file channel ---
grep -q 'SetUserVar' "$LIB"; assert_exit "$?" "1" "no SetUserVar OSC emit remains"
grep -q '/dev/tty' "$LIB"; assert_exit "$?" "1" "no /dev/tty write remains"

# --- Part 3: Windows branch writes the pane-keyed alert file ---
STUB="$(mktemp -d)"
cat > "$STUB/uname" <<'EOF'
#!/usr/bin/env bash
echo "MINGW64_NT-10.0-26200"
EOF
PSLOG="$(mktemp)"
printf '#!/usr/bin/env bash\nprintf "called\\n" >> "%s"\nexit 0\n' "$PSLOG" > "$STUB/powershell.exe"
printf '#!/usr/bin/env bash\necho "$2"\n' > "$STUB/cygpath"
chmod +x "$STUB"/*
export PATH="$STUB:$PATH"

export CC_ALERT_DIR="$(mktemp -d)"
export WEZTERM_PANE=42
unset TMUX TMUX_PANE            # exercise only the Windows path
. "$LIB"

cc_notify "Claude Code" "needs you" notification
assert_eq "$(cat "$CC_ALERT_DIR/42" 2>/dev/null)" "notification" "writes 'notification' to pane 42's alert file"
assert_contains "$(cat "$PSLOG")" "called" "desktop toast notifier still invoked"

cc_notify "Claude Code" "done" stop
assert_eq "$(cat "$CC_ALERT_DIR/42" 2>/dev/null)" "stop" "stop overwrites the same pane's alert file"

cc_notify "Claude Code" "hi"   # kind omitted -> defaults to notification
assert_eq "$(cat "$CC_ALERT_DIR/42" 2>/dev/null)" "notification" "kind defaults to notification"

# --- Part 4: no WEZTERM_PANE -> no file written (graceful no-op) ---
rm -f "$CC_ALERT_DIR"/*
unset WEZTERM_PANE
cc_notify "Claude Code" "no pane" notification
assert_eq "$(ls -A "$CC_ALERT_DIR")" "" "no alert file written when WEZTERM_PANE is unset"

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-notify-windows.sh`
Expected: FAIL — Part 2 fails because the lib still contains `SetUserVar` and `/dev/tty` (`FAIL: no SetUserVar OSC emit remains`), and Part 3 fails because no `42` file is written (`FAIL: writes 'notification' to pane 42's alert file (expected 'notification', got '')`).

- [ ] **Step 3: Replace the OSC emit with the file write**

In `claude/hooks/lib/notify-lib.sh`, inside the `MINGW*|MSYS*|CYGWIN*|Windows_NT)` branch, replace this block:

```bash
      # Tab-badge cue: set the claude_status WezTerm user var on this pane's terminal
      # so the tab bar can flag which tab is waiting, without switching to it (see
      # .config/wezterm/tabline_claude_badge.lua). Invisible OSC; CC_TTY is a test seam.
      printf '\033]1337;SetUserVar=claude_status=%s\007' \
        "$(printf '%s' "$kind" | base64 | tr -d '\n')" > "${CC_TTY:-/dev/tty}" 2>/dev/null || true
```

with:

```bash
      # Tab-badge cue: record which WezTerm pane is waiting, keyed by $WEZTERM_PANE, so the
      # tab bar can flag it without switching (see .config/wezterm/tabline_claude_badge.lua +
      # the update-status poller in wezterm.lua). File channel -- robust on Windows, where
      # OSC-through-ConPTY to WezTerm does not arrive. CC_ALERT_DIR is a test seam.
      if [ -n "${WEZTERM_PANE:-}" ]; then
        local alert_dir="${CC_ALERT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-notify/wezterm-alerts}"
        mkdir -p "$alert_dir" 2>/dev/null \
          && printf '%s' "$kind" > "$alert_dir/$WEZTERM_PANE" 2>/dev/null || true
      fi
```

(Leave the desktop-toast block below it — the `notifier_sh` lines — unchanged.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-notify-windows.sh`
Expected: PASS — all `PASS:` lines, ending `--- 11 run, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add -- claude/hooks/lib/notify-lib.sh claude/hooks/tests/test-notify-windows.sh
git commit -m "feat(hooks): write pane-keyed alert file instead of OSC on Windows" -- claude/hooks/lib/notify-lib.sh claude/hooks/tests/test-notify-windows.sh
```

---

### Task 3: Renderer — badge reads only precise alerts

**Files:**
- Rewrite: `.config/wezterm/tabline_claude_badge.lua`
- Modify (test): `claude/hooks/tests/test-tabline-claude-badge.lua`

**Interfaces:**
- Consumes: `wezterm.GLOBAL.claude_alert` = `{ [pane_id_string] = "notification"|"stop" }` (written by the Task 4 poller). The component reads it; it must not mutate it.
- Produces: sets `opts.icon` and returns `' '` (badge) or `nil` (no badge). Unchanged tabline component contract.

- [ ] **Step 1: Update the test first**

Replace the entire contents of `claude/hooks/tests/test-tabline-claude-badge.lua` with:

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
  nerdfonts = { md_bell_ring = "RING", md_bell = "BELL" },
  GLOBAL = {},
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

-- 3. unseen output but NO claude alert -> no badge (fallback tier removed)
stub.GLOBAL.claude_alert = {}
opts = {}
r = badge.update(tab(false, { pane(9, true) }), opts)
ok(r == nil, "unseen output without an alert renders nothing")
ok(opts.icon == nil, "unseen output sets no icon")

-- 4. no alert at all -> no badge
stub.GLOBAL.claude_alert = {}
opts = {}
r = badge.update(tab(false, { pane(9, false) }), opts)
ok(r == nil, "no alert renders nothing")

-- 5. active tab -> no badge, and the component does NOT mutate GLOBAL
--    (the update-status poller in wezterm.lua owns all clearing now).
stub.GLOBAL.claude_alert = { ["5"] = "notification" }
opts = {}
r = badge.update(tab(true, { pane(5) }), opts)
ok(r == nil, "active tab renders no badge")
ok(stub.GLOBAL.claude_alert["5"] == "notification", "component leaves GLOBAL untouched (poller clears)")

-- 6. alert present and pane also has unseen output -> alert still wins
stub.GLOBAL.claude_alert = { ["5"] = "notification" }
opts = {}
badge.update(tab(false, { pane(5, true) }), opts)
ok(opts.icon[1] == "RING", "alert renders regardless of unseen output")

print(string.format("--- %d passed, %d failed ---", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-tabline-claude-badge.sh`
Expected: FAIL — case 3 fails because the current component renders the `md_bell_outline` fallback for unseen output (`FAIL: unseen output without an alert renders nothing`), and case 5 fails because the current component clears the entry (`FAIL: component leaves GLOBAL untouched (poller clears)`).

- [ ] **Step 3: Rewrite the component as a pure reader**

Replace the entire contents of `.config/wezterm/tabline_claude_badge.lua` with:

```lua
local wezterm = require('wezterm')

-- Catppuccin Frappe tokens (kept local so the badge stays on-theme; change here if the
-- flavour ever changes).
local frappe = {
  crust  = '#232634',
  peach  = '#ef9f76',
  yellow = '#e5c890',
}

return {
  default_opts = {},
  update = function(tab, opts)
    -- Never badge the tab you're on (the update-status poller also clears its alert
    -- on focus). The poller is the sole writer of GLOBAL.claude_alert; this component
    -- only reads it.
    if tab.is_active then return end
    local alerts = wezterm.GLOBAL.claude_alert or {}
    local kind
    for _, p in ipairs(tab.panes) do
      kind = kind or alerts[tostring(p.pane_id)]
    end
    if kind == 'notification' then
      opts.icon = { wezterm.nerdfonts.md_bell_ring, color = { fg = frappe.crust, bg = frappe.peach } }
      return ' '
    elseif kind == 'stop' then
      opts.icon = { wezterm.nerdfonts.md_bell, color = { fg = frappe.crust, bg = frappe.yellow } }
      return ' '
    end
  end,
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-tabline-claude-badge.sh`
Expected: PASS — ending `--- 12 passed, 0 failed ---` then `PASS: tabline_claude_badge.lua unit tests pass` and `--- 1 run, 0 failed ---`.

- [ ] **Step 5: Commit**

```bash
git add -- .config/wezterm/tabline_claude_badge.lua claude/hooks/tests/test-tabline-claude-badge.lua
git commit -m "refactor(wezterm): Claude badge renders only precise alerts" -- .config/wezterm/tabline_claude_badge.lua claude/hooks/tests/test-tabline-claude-badge.lua
```

---

### Task 4: Reconciler — wire the poller into wezterm.lua

**Files:**
- Modify: `.config/wezterm/wezterm.lua` (inside `if is_windows then`): add the `require`, add the reconcile pass to the existing `update-status` handler (currently lines 333-343), remove the `user-var-changed` handler (currently lines 345-357)
- Create (test): `claude/hooks/tests/test-wezterm-wiring.sh`

**Interfaces:**
- Consumes (from Task 1): `claude_alerts.dir(home, xdg_cache)`, `claude_alerts.reconcile(paths, live, visited, read_file, remove)`.
- Produces (runtime): `wezterm.GLOBAL.claude_alert` for the Task 3 component.

> **Note on verification:** `wezterm.lua` cannot be executed outside WezTerm (it calls `wezterm.plugin.require` at runtime), so this task's automated gate is structural (greps) plus a `loadfile` **syntax** check. True runtime behaviour is verified in Task 5 (manual GUI acceptance).

- [ ] **Step 1: Write the failing test**

Create `claude/hooks/tests/test-wezterm-wiring.sh`:

```bash
#!/usr/bin/env bash
# Static + parse gate for the Claude badge wiring in wezterm.lua. The poller cannot
# be executed outside WezTerm, so we assert structure and that the file still parses.
. "$(dirname "$0")/_harness.sh"

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"   # tests -> hooks -> claude -> repo root
WT="$repo_root/.config/wezterm/wezterm.lua"

grep -q "require('wezterm_claude_alerts')" "$WT"; assert_exit "$?" "0" "wezterm.lua requires the reconcile module"
grep -q "claude_alerts.reconcile(" "$WT"; assert_exit "$?" "0" "wezterm.lua calls reconcile() in update-status"
grep -q "user-var-changed" "$WT"; assert_exit "$?" "1" "user-var-changed handler removed"
grep -q "package.loaded\['tabline.components.tab.claude'\]" "$WT"; assert_exit "$?" "0" "badge component still registered"

if command -v lua >/dev/null 2>&1; then
  WT_PATH="$WT" lua -e "assert(loadfile(os.getenv('WT_PATH')))"
  assert_exit "$?" "0" "wezterm.lua parses (loadfile)"
else
  echo "  SKIP: lua not installed (wezterm.lua parse check)"
fi
finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash claude/hooks/tests/test-wezterm-wiring.sh`
Expected: FAIL — the module is not required yet (`FAIL: wezterm.lua requires the reconcile module`), reconcile is not called (`FAIL: wezterm.lua calls reconcile() in update-status`), and the old handler is still present (`FAIL: user-var-changed handler removed`).

- [ ] **Step 3a: Require the module**

In `.config/wezterm/wezterm.lua`, find this line (inside the `if is_windows then` block, ~line 329):

```lua
    -- Track the previously-active workspace so Leader+L can jump back (tmux `prefix + L`).
```

Insert immediately **before** it:

```lua
    -- Reconcile module for the Claude tab-badge alert dir (pure logic, unit-tested in
    -- claude/hooks/tests/test-claude-alerts.lua).
    local claude_alerts = require('wezterm_claude_alerts')

```

- [ ] **Step 3b: Add the reconcile pass to the update-status handler**

Replace this existing handler (the workspace-tracking `update-status`, ~lines 333-343):

```lua
    wezterm.on("update-status", function(window)
        local current = window:active_workspace()
        if wezterm.GLOBAL.current_workspace ~= current then
            -- GLOBAL is purpose-built to hold arbitrary cross-reload state; LuaLS types it
            -- as opaque userdata, so silence its inject-field nag on these two writes.
            ---@diagnostic disable-next-line: inject-field
            wezterm.GLOBAL.previous_workspace = wezterm.GLOBAL.current_workspace
            ---@diagnostic disable-next-line: inject-field
            wezterm.GLOBAL.current_workspace = current
        end
    end)
```

with (same handler, plus the reconcile pass before its `end)`):

```lua
    wezterm.on("update-status", function(window)
        local current = window:active_workspace()
        if wezterm.GLOBAL.current_workspace ~= current then
            -- GLOBAL is purpose-built to hold arbitrary cross-reload state; LuaLS types it
            -- as opaque userdata, so silence its inject-field nag on these two writes.
            ---@diagnostic disable-next-line: inject-field
            wezterm.GLOBAL.previous_workspace = wezterm.GLOBAL.current_workspace
            ---@diagnostic disable-next-line: inject-field
            wezterm.GLOBAL.current_workspace = current
        end

        -- Claude tab badge: reconcile the pane-keyed alert dir into GLOBAL.claude_alert.
        -- Sole writer of that table; prunes dead panes and clears the visited tab.
        local dir = claude_alerts.dir(wezterm.home_dir, os.getenv('XDG_CACHE_HOME'))
        local paths = {}
        pcall(function() paths = wezterm.read_dir(dir) end)   -- missing dir -> {}
        local live = {}
        for _, w in ipairs(wezterm.mux.all_windows()) do
            for _, t in ipairs(w:tabs()) do
                for _, p in ipairs(t:panes()) do
                    live[tostring(p:pane_id())] = true
                end
            end
        end
        local visited = {}
        local at = window:active_tab()
        if at then
            for _, p in ipairs(at:panes()) do
                visited[tostring(p:pane_id())] = true
            end
        end
        local function read_file(path)
            local fh = io.open(path, 'r'); if not fh then return nil end
            local s = fh:read('*a'); fh:close(); return s
        end
        ---@diagnostic disable-next-line: inject-field
        wezterm.GLOBAL.claude_alert = claude_alerts.reconcile(paths, live, visited, read_file, os.remove)
    end)
```

- [ ] **Step 3c: Remove the user-var-changed handler**

Delete this entire block (the comment + handler, ~lines 345-357), including the blank line above it:

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
        ---@diagnostic disable-next-line: inject-field
        wezterm.GLOBAL.claude_alert = t
    end)
```

(The `package.loaded['tabline.components.tab.claude'] = require('tabline_claude_badge')` registration and the `"claude"` entry in `tab_inactive` stay as they are.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash claude/hooks/tests/test-wezterm-wiring.sh`
Expected: PASS — `wezterm.lua requires the reconcile module`, `calls reconcile() in update-status`, `user-var-changed handler removed`, `badge component still registered`, `wezterm.lua parses (loadfile)`; ending `--- 5 run, 0 failed ---`.

- [ ] **Step 5: Check LSP diagnostics**

Open `.config/wezterm/wezterm.lua` and confirm no **new** diagnostics from the added code (the `---@diagnostic disable-next-line: inject-field` lines suppress the GLOBAL-write nags, matching the existing convention). Pre-existing warnings elsewhere in the file are out of scope.

- [ ] **Step 6: Commit**

```bash
git add -- .config/wezterm/wezterm.lua claude/hooks/tests/test-wezterm-wiring.sh
git commit -m "feat(wezterm): poll Claude alert dir in update-status, drop OSC handler" -- .config/wezterm/wezterm.lua claude/hooks/tests/test-wezterm-wiring.sh
```

---

### Task 5: Manual GUI acceptance (operator-only — no automated gate)

**Files:** none. This task is run by the human operator in a live WezTerm session; the agent cannot perform it. It verifies the runtime integration the static tests cannot.

- [ ] **Step 1: Reload WezTerm config** — `Ctrl+Shift+R`. Expect no error toast (confirms `wezterm.lua` loaded, the new `require` resolved, and the badge component still registered).

- [ ] **Step 2: Confirm the directory contract resolves** — in a Git Bash pane, run `echo "$HOME/.cache/claude-notify/wezterm-alerts"` and confirm it points under your Windows user profile (e.g. `C:\Users\<you>\.cache\…`). If `$HOME` here does not match WezTerm's home dir, badges won't appear — report it.

- [ ] **Step 2 (alt): live signal smoke** — from a non-Claude tab, write a fake alert for a Claude pane and watch the badge appear within ~1s:
  `printf stop > "$HOME/.cache/claude-notify/wezterm-alerts/<that-pane-id>"` (get the id from `echo $WEZTERM_PANE` in the target pane). Visit the tab → badge clears and the file is removed.

- [ ] **Step 3: Real "needs you"** — in a Claude tab, trigger a permission prompt while focused elsewhere. Expect: **no tab switch**; that tab shows a **peach** `md_bell_ring`. Visit it → badge clears.

- [ ] **Step 4: Real "finished"** — let a Claude turn complete while focused elsewhere. Expect a **yellow** `md_bell`; visiting clears it.

- [ ] **Step 5: No clutter** — run a build / `tail -f` / `nvim` in a **non-Claude** tab and tab away. Expect **no badge** (the `has_unseen_output` fallback is gone).

- [ ] **Step 6: Independence** — with two Claude tabs, confirm each flags only when its own Claude needs you, and visiting one does not clear the other.

- [ ] **Step 7 (regression sanity):** run the feature's automated tests together and confirm green:
  `for t in test-claude-alerts test-notify-windows test-tabline-claude-badge test-wezterm-wiring; do bash "claude/hooks/tests/$t.sh"; done`
  (Do not use `run-tests.sh`; its `test-cc-notify-pending.sh` has pre-existing macOS-only failures on Windows — out of scope.)

---

## Self-Review

**1. Spec coverage:**
- "bell only for Claude attention; fallback removed" → Task 3 (component rewrite) + test case 3. ✓
- "signal via `$WEZTERM_PANE` file, not OSC" → Task 2 (producer) + Part 2/3 assertions. ✓
- "poller is sole writer; reconcile dead/visited" → Task 4 + Task 1 `reconcile` (tested in Task 1). ✓
- "remove `user-var-changed`" → Task 4 Step 3c + wiring test. ✓
- "extracted, unit-testable reconcile" → Task 1 module + test. ✓
- "directory contract" → Global Constraints + Task 1 `dir()` + Task 2 `alert_dir` (identical string). ✓
- "colors/glyphs verbatim" → Global Constraints + Task 3 component + test. ✓
- "no-WezTerm graceful no-op; FS-failure safe" → Task 2 Part 4 + the `|| true` writes. ✓
- "edge cases: stale/dead panes, concurrent Claudes, active-tab" → Task 1 reconcile tests + Task 3 case 5/6. ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows complete content; every run step gives an exact command and expected output. ✓

**3. Type/name consistency:**
- `M.dir(home, xdg_cache)` / `M.reconcile(paths, live, visited, read_file, remove)` — identical signatures in Task 1 module, Task 1 test, and Task 4 call site. ✓
- Dir string `…/claude-notify/wezterm-alerts` identical in `M.dir` (Task 1), `alert_dir` (Task 2), and Global Constraints. ✓
- Kinds `notification`/`stop` and colors `#ef9f76`/`#e5c890`/`#232634` consistent across producer, component, and both Lua tests. ✓
- `wezterm.GLOBAL.claude_alert` keyed by **string** pane ids everywhere: producer filename `$WEZTERM_PANE`, `reconcile` keys via `tostring`-free string match on the basename, poller builds `live`/`visited` with `tostring(p:pane_id())`, component reads `alerts[tostring(p.pane_id)]`. ✓

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-25-wezterm-claude-tab-badge-file-channel.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**

# tmux Adaptive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the tmux status bar adapt per client by terminal width — a wide PC client keeps the full UI; a narrow client (phone over SSH, same server) shows a minimal UI — using one tunable threshold.

**Architecture:** tmux renders the status line separately for each attached client, so `#{client_width}` is per-client. A single render-time ternary on `#{client_width}` (numeric `#{e|>=:}`) selects between a full and minimal `status-right`, with all Catppuccin module tokens **inlined** (an `@status_right_full` indirection was tested and rejected — the extra `#{E:}` pass collapses cpu/battery's `#{l:}`-protected interpolations to empty). The window list reuses the same width branch via a one-line conditional on the inactive-tab text variable.

**Tech Stack:** tmux 3.4 (`/usr/bin/tmux`), Catppuccin tmux theme (frappe), tmux-cpu / tmux-battery plugins, TPM. Single file changed: `tmux/tmux.conf`. No test framework in this repo (dotfiles) — verification uses an **isolated tmux server** (`-L adapt_test`) plus manual per-client checks.

**Design reference:** `docs/superpowers/specs/2026-06-15-tmux-adaptive-status-bar-design.md`

**Conventions for this plan:**
- Run all isolated-server commands from the **repo root**. Use `command tmux` to bypass the oh-my-zsh `tmux` shell function (the real binary is `/usr/bin/tmux`); if `command tmux` ever resolves wrong, substitute `/usr/bin/tmux`.
- Tests load the **working-tree file** `tmux/tmux.conf` directly (not `~/.tmux.conf`), so they validate your edits even inside a git worktree.
- `#{client_width}` is **empty** in a *detached* isolated server (no client). Tests therefore validate branch *logic* by substituting literal widths (`200`, `50`); true per-client width differentiation is validated manually in Task 5 on the real session.

---

### Task 1: Create the working branch

**Files:** none (git only).

- [ ] **Step 1: Branch off master**

The working tree has unrelated pre-existing edits (`claude/settings.json`, `zsh/zshrc.sh`) — **do not** stage or commit those; this plan only touches `tmux/tmux.conf` and the docs already written.

Run:
```bash
git checkout -b feat/tmux-adaptive-ui
```

- [ ] **Step 2: Confirm branch**

Run:
```bash
git branch --show-current
```
Expected: `feat/tmux-adaptive-ui`

---

### Task 2: Red — capture current (pre-change) behavior

**Files:** none (read-only validation).

- [ ] **Step 1: Confirm there is no width threshold or width ternary today**

Run:
```bash
command tmux -L adapt_test kill-server 2>/dev/null
command tmux -L adapt_test -f tmux/tmux.conf new-session -d -s SESSX -x 200 -y 50
sleep 1
echo "--- threshold (expect empty/unset) ---"
command tmux -L adapt_test show -gv @ui_full_min_width 2>&1
echo "--- status-right contains a width ternary? (expect: no match) ---"
command tmux -L adapt_test show -gv status-right | grep -c 'e|>=' || true
command tmux -L adapt_test kill-server 2>/dev/null
```
Expected:
- threshold line prints empty (option not set).
- the `grep -c 'e|>='` prints `0` (no width ternary yet).

This is the "red" baseline: full modules always, no per-width adaptation.

---

### Task 3: Adaptive right side (`status-right`)

**Files:**
- Modify: `tmux/tmux.conf` (the `status-right` assembly block, currently lines ~49–68)

- [ ] **Step 1: Replace the `status-right` assembly block**

Use this exact find/replace on `tmux/tmux.conf`.

Find:
```tmux
set -g status-right-length 100
set -g status-left-length 100
set -g status-left ""
# Reset status-right before TPM runs so tmux-continuum doesn't inherit the
# default tmux format string ("#{=21:pane_title}" %H:%M %d-%b-%y)
set -g status-right ""
# Status bar right side modules (order: application | datetime | cpu | session | uptime | battery)
# -agF: append with format expansion, -ag: append without format expansion
set -agF status-right "#{E:@catppuccin_status_application}"
set -ag status-right "#{E:@catppuccin_status_date_time}"
set -agF status-right "#{E:@catppuccin_status_cpu}"
set -ag status-right "#{E:@catppuccin_status_session}"
set -ag status-right "#{E:@catppuccin_status_uptime}"
# maybe use upower?
# if-shell 'command -v upower >/dev/null && upower -e | grep -q battery' \
#    'set -agF status-right "#{E:@catppuccin_status_battery}"'
if-shell '[ -d /sys/class/power_supply/BAT0 ] || ls /sys/class/power_supply/BAT* >/dev/null 2>&1' \
    'set -agF status-right "#{E:@catppuccin_status_battery}"'
if-shell '[ "$(uname)" = "Darwin" ] && pmset -g batt 2>/dev/null | grep -q Battery' \
    'set -agF status-right "#{E:@catppuccin_status_battery}"'
```

Replace with:
```tmux
set -g status-right-length 100
set -g status-left-length 100
set -g status-left ""

# Width threshold (columns): clients >= this render the FULL UI; narrower
# clients (e.g. phone over SSH) render the MINIMAL one. Drives BOTH the
# right side and the window list (Catppuccin window text below).
# Measure your phone once while attached:  tmux display -p '#{client_width}'
# then set this between the phone width and your PC width.
set -g @ui_full_min_width "120"

# Battery presence flag (static per host): the battery module renders only on
# real battery hardware. Set once at load; referenced inline in status-right.
set -g @has_batt ""
# (upower alternative kept commented for reference)
# if-shell 'command -v upower >/dev/null && upower -e | grep -q battery' 'set -g @has_batt "1"'
if-shell '[ -d /sys/class/power_supply/BAT0 ] || ls /sys/class/power_supply/BAT* >/dev/null 2>&1' \
    'set -g @has_batt "1"'
if-shell '[ "$(uname)" = "Darwin" ] && pmset -g batt 2>/dev/null | grep -q Battery' \
    'set -g @has_batt "1"'

# Per-client status-right. The status line renders per client, so #{client_width}
# is that client's own width. Plain `set -g` (no -F) stores the #{E:...} tokens
# literally and defers all expansion to render time (after Catppuccin loads via
# TPM). Modules are INLINED (not via an @status_right_full indirection, which
# breaks cpu/battery — the extra #{E:} pass eats their #{l:}-protected values).
# Numeric comparison MUST use #{e|>=:...}; bare #{>=:...} is a STRING compare.
#   FULL (wide):  application | datetime | cpu | session | uptime | [battery]
#   MIN  (narrow): session only
set -g status-right "#{?#{e|>=:#{client_width},#{@ui_full_min_width}},#{E:@catppuccin_status_application}#{E:@catppuccin_status_date_time}#{E:@catppuccin_status_cpu}#{E:@catppuccin_status_session}#{E:@catppuccin_status_uptime}#{?@has_batt,#{E:@catppuccin_status_battery},},#{E:@catppuccin_status_session}}"
```

- [ ] **Step 2: Validate in an isolated server (the "green" check)**

Run (from repo root):
```bash
command tmux -L adapt_test kill-server 2>/dev/null
command tmux -L adapt_test -f tmux/tmux.conf new-session -d -s SESSX -x 200 -y 50 || { echo "FAIL: config did not load (syntax error)"; exit 1; }
sleep 1

echo "--- threshold == 120 ---"
command tmux -L adapt_test show -gv @ui_full_min_width

echo "--- status-right is a numeric width ternary referencing client_width ---"
command tmux -L adapt_test show -gv status-right | grep -q 'e|>=:#{client_width},#{@ui_full_min_width}' && echo "OK ternary" || echo "FAIL ternary"

echo "--- REGRESSION GUARD: FULL branch keeps cpu LIVE (inline, not collapsed) ---"
# Force the wide branch with a literal 200 (detached server has empty client_width).
FULL='#{E:@catppuccin_status_application}#{E:@catppuccin_status_cpu}#{E:@catppuccin_status_session}'
OUT="$(command tmux -L adapt_test display -p "#{?#{e|>=:200,120},${FULL},MIN}")"
echo "$OUT"
case "$OUT" in
  *'#[fg=,bg=]'*) echo "FAIL: cpu collapsed to empty style (indirection leaked back in)";;
  *cpu_percentage*) echo "OK: cpu interpolation intact (inline)";;
  *) echo "WARN: inspect output above";;
esac
case "$OUT" in *SESSX*) echo "OK: session present in full branch";; *) echo "FAIL: session missing";; esac

echo "--- MIN branch (narrow) renders session only ---"
MOUT="$(command tmux -L adapt_test display -p '#{?#{e|>=:50,120},FULLBRANCH,#{E:@catppuccin_status_session}}')"
echo "$MOUT"
case "$MOUT" in *SESSX*) echo "OK: session shown when narrow";; *) echo "FAIL";; esac
case "$MOUT" in *e5c890*) echo "FAIL: cpu style present when narrow";; *) echo "OK: no cpu when narrow";; esac

command tmux -L adapt_test kill-server 2>/dev/null
```
Expected: `120`; `OK ternary`; `OK: cpu interpolation intact (inline)`; `OK: session present in full branch`; `OK: session shown when narrow`; `OK: no cpu when narrow`. **If you see `FAIL: cpu collapsed`**, the indirection form was used — re-check Step 1 used inlined `#{E:@catppuccin_status_*}` tokens directly in the ternary.

- [ ] **Step 3: Commit**

```bash
git add tmux/tmux.conf
git commit -m "$(cat <<'EOF'
feat(tmux): width-adaptive status-right (full on PC, minimal over SSH)

Render status-right per client via a #{client_width} ternary: wide clients
get the full module chain, narrow clients (phone over SSH to the same server)
get session-only. Modules are inlined to preserve cpu/battery liveness; battery
is gated by an @has_batt flag. Threshold @ui_full_min_width (default 120).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Adaptive window list (inactive tabs collapse to index)

**Files:**
- Modify: `tmux/tmux.conf` (the `@catppuccin_window_text` line, currently line ~46)

- [ ] **Step 1: Make the inactive-tab text width-conditional**

The index (`#I`) is rendered by Catppuccin *outside* this variable, so emptying the text on narrow clients leaves the index visible. `@catppuccin_window_current_text` (the active tab) is intentionally left unchanged.

Find:
```tmux
set -g @catppuccin_window_text " #W"
```

Replace with:
```tmux
# Inactive tabs: window name on wide clients; empty (index only) on narrow
# clients. The index #I is rendered by Catppuccin outside this variable.
# Catppuccin inlines this value raw into window-status-format and defers it to
# render time, so #{client_width} resolves per client. Numeric compare: e|>=.
set -g @catppuccin_window_text "#{?#{e|>=:#{client_width},#{@ui_full_min_width}}, #W,}"
```

- [ ] **Step 2: Validate in an isolated server**

Run (from repo root):
```bash
command tmux -L adapt_test kill-server 2>/dev/null
command tmux -L adapt_test -f tmux/tmux.conf new-session -d -s SESSX -x 200 -y 50 || { echo "FAIL: config did not load"; exit 1; }
sleep 1

echo "--- @catppuccin_window_text is the width conditional ---"
command tmux -L adapt_test show -gv @catppuccin_window_text | grep -q 'e|>=:#{client_width},#{@ui_full_min_width}' && echo "OK window text conditional" || echo "FAIL window text"

echo "--- Catppuccin inlined it into window-status-format (deferred client_width) ---"
command tmux -L adapt_test show -gv window-status-format | grep -q 'client_width' && echo "OK inlined into window-status-format" || echo "FAIL: not inlined (is the line before 'run tpm'?)"

echo "--- current-tab format still carries name + path (unchanged) ---"
command tmux -L adapt_test show -gv window-status-current-format | grep -q 'pane_current_path' && echo "OK current tab keeps path" || echo "FAIL: current tab changed"

command tmux -L adapt_test kill-server 2>/dev/null
```
Expected: `OK window text conditional`; `OK inlined into window-status-format`; `OK current tab keeps path`.

- [ ] **Step 3: Commit**

```bash
git add tmux/tmux.conf
git commit -m "$(cat <<'EOF'
feat(tmux): width-adaptive window tabs (inactive tabs -> index only when narrow)

On narrow clients the inactive tab text collapses to empty so only the index
shows; the current tab keeps index + name + path. Same @ui_full_min_width
threshold as status-right. One-line conditional on @catppuccin_window_text.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Green — live per-client verification on the real session

**Files:** none (manual checks on the user's actual tmux). This is the only place true per-client width differentiation is exercised; do it on the real machine, ideally with the phone.

> If you implemented in a git worktree, note that `~/.tmux.conf` still points at the **main** working tree. Either run these checks after merging (Task 6), or temporarily reload the worktree file: `tmux source-file "$PWD/tmux/tmux.conf"`.

- [ ] **Step 1: Reload the real config**

In your running tmux session:
```bash
tmux source-file ~/.tmux.conf
```
Open at least two windows (`prefix c`) so the tab list is meaningful.

- [ ] **Step 2: Wide (PC) checks**

- Right side shows the full chain: application | date_time | cpu | session | uptime | [battery only on a laptop].
- Every tab shows index + name; the current tab also shows the path and (if zoomed) the zoom glyph.
- Watch ~1 minute: the clock advances and CPU % changes (confirms inline tokens render live, not as literal `#{cpu_percentage}`).

- [ ] **Step 3: Narrow checks**

Shrink the terminal below 120 columns (or attach from the phone). Confirm `tmux display -p '#{client_width}'` reports `< 120`, then:
- Right side shows **only** the session module.
- Inactive tabs show **index only** (e.g. `1  2  3`); the current tab still shows index + name + path.
- Switch the active window (`prefix n`): the previously-current tab collapses to index-only and the newly-current expands. Both clients update independently if PC + phone are attached at once.

- [ ] **Step 4: Boundary check (numeric, not string, comparison)**

With a client sized to ~119 columns, confirm the UI is minimal; at ~121 columns, confirm it's full. (If 80-wide showed *full*, a bare string `>=` slipped in instead of `e|>=`.)

- [ ] **Step 5: Tune the threshold if needed**

If your phone's real width sits above 120 (so it wrongly gets the full bar) or a PC split you want full sits below 120, edit the single knob in `tmux/tmux.conf`:
```tmux
set -g @ui_full_min_width "120"   # set between your phone width and PC width
```
Reload (`tmux source-file ~/.tmux.conf`) and re-check. If you change it, amend or add a commit.

---

### Task 6: Wrap up

**Files:** none (git).

- [ ] **Step 1: Review the two commits**

```bash
git log --oneline master..feat/tmux-adaptive-ui
git diff master..feat/tmux-adaptive-ui -- tmux/tmux.conf
```
Expected: two `feat(tmux):` commits; the diff touches only `tmux/tmux.conf`.

- [ ] **Step 2: Integrate (ask the user first — do not auto-merge)**

No redeploy is needed: `~/.tmux.conf` already symlinks to the repo file, so a `tmux source-file` (Task 5) is the only activation step. When the user approves, fast-forward master:
```bash
git checkout master && git merge --ff-only feat/tmux-adaptive-ui
```
(Or open a PR if the user prefers review.) Leave the pre-existing unrelated changes in `claude/settings.json` / `zsh/zshrc.sh` untouched.

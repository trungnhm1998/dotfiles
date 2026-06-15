# tmux Adaptive Status Bar (width-aware full / minimal)

- **Date:** 2026-06-15
- **Status:** Approved (design)
- **Scope:** `tmux/tmux.conf` only

## Problem

The tmux status bar shows a full set of right-side modules — `application` (process), `date_time`, `cpu`, `session`, `uptime`, `battery` — plus a left/window list where every tab shows its index + name. On a wide PC monitor this is fine, but when SSHing into the **same PC from a phone** and attaching to the already-running session, the narrow phone screen is cluttered: irrelevant right-side modules (the phone already has its own clock/battery) and a window list where inactive tab names eat horizontal space.

The goal: the **PC client keeps the full UI** while the **phone client shows a minimal UI**, **simultaneously**, from the same tmux server. Two coordinated pieces, both driven by one width threshold:

1. **Right side** — full module chain on wide clients; session name only on narrow.
2. **Left / window list** — on narrow clients, inactive tabs collapse to **index only** while the current tab keeps its full **index + name + path** detail.

## Goals

- Wide clients render the existing full right-side module chain unchanged.
- Narrow clients render a minimal right-side bar: **session name only**.
- Narrow clients render inactive window tabs as **index only**; the current tab is **unchanged** (index + name + path + zoom flag) in both modes.
- All behaviors apply **per client at the same time** (PC + phone attached to the same server/session).
- No new plugins, no hooks, no server restart; a single tunable threshold drives both pieces.

## Non-Goals

- Literal "is this an SSH connection" detection (see Rejected Alternatives — not cleanly possible per-client for this topology).
- Trimming the current/active tab on narrow clients (it deliberately keeps full index + name + path, per decision).
- Solving tmux's shared-window resize behavior (the content area shrinks to the smallest attached client; out of scope — the status *bar* is unaffected, see Edge Cases).

## Topology (why this approach)

The phone SSHes into the **same PC** and attaches to the **already-running** tmux session. That means:

- One tmux server, started locally (no `$SSH_CONNECTION` at server start), so a load-time `if-shell $SSH_CONNECTION` check cannot work.
- PC and phone may be attached **at the same time**, sharing one session — and `status-right` is a single session/global option, so it cannot be "set" to two different values.

The only race-free way to make one option render differently per client is **per-client format evaluation**: tmux draws the status line separately for each attached client, and `#{client_width}` resolves to that specific client's terminal width. The phone is narrow; the PC is wide. Width is therefore both the available signal *and* the real cause of the clutter.

## Approach (chosen: A — per-client width branch)

Set `status-right` to a single render-time ternary on `#{client_width}` that **inlines** the module tokens directly in each branch:

- **Full branch** (wide): `#{E:@catppuccin_status_application}` + `…_date_time` + `…_cpu` + `…_session` + `…_uptime` + (battery, gated).
- **Minimal branch** (narrow): `#{E:@catppuccin_status_session}` only.
- The comma-laden `#[fg=…,bg=…]` styles live *inside* the resolved option values, not in the ternary literal, so the branches contain only comma-free `#{E:@…}` tokens — no format-parser comma trap.

The **window list** reuses the identical per-client width branch: a one-line conditional on the inactive-tab text variable (see Detailed Design → Left / window list). Both pieces read the same `@ui_full_min_width` threshold.

### Why inline — and why the `@status_right_full` indirection was rejected (validated on tmux 3.4)

An earlier design routed the branches through a prebuilt `@status_right_full` option (`#{E:@status_right_full}`). **Live testing disproved it.** Comparing a module rendered at top level vs. inside the construct:

- **Inline** (`#{?cond,#{E:@catppuccin_status_cpu},…}`) → byte-identical to the top-level `#{E:@catppuccin_status_cpu}`. ✅
- **Indirection** (`#{E:@status_right_full}` where the option contains `#{E:@catppuccin_status_cpu}`) → the extra `#{E:}` pass **prematurely consumed** the `#{l:}`-protected interpolations: `#{cpu_fg_color}`/`#{cpu_bg_color}`/`#{cpu_percentage}` collapsed to empty, rendering `#[fg=,bg=]` with no value. ❌ (Same failure would hit `battery`.)

So inline is the design: each `#{E:@catppuccin_status_*}` token sits at the **exact single-`#{E:}` depth the working config already uses**, guaranteeing identical liveness. `session`/`date_time`/`uptime` (deferred) and `cpu`/`battery` (`#{l:}`-protected) all resolve correctly inline — confirmed against the real Catppuccin modules.

Battery is the only conditional module (shown only on battery hardware). It's gated with a **presence flag** `@has_batt` set at load time, referenced inline as `#{?@has_batt,#{E:@catppuccin_status_battery},}` — keeping battery at the same single-`#{E:}` depth. (Flag truthiness `#{?@has_batt,…,}` verified.)

### Comparison operator (validated)

Use the **numeric** comparison `#{e|>=:a,b}` — the `e|` prefix is required. Tested on tmux 3.4: bare `#{>=:80,120}` → `1` (it's a *string* compare, `"80" ≥ "120"` lexically — wrong for widths), while `#{e|>=:80,120}` → `0` (correct numeric). The man page confirms: bare `<`/`>`/`>=` are *string* comparisons; the numeric operators live under the `e|` arithmetic modifier. (Catppuccin's bare `#{==:…}` works only because string and numeric equality coincide — that does not generalize to inequalities.)

Also note: a `#{?cond,…}` condition must be a **format that evaluates to non-zero/non-empty**, e.g. `#{e|>=:…}` or a defined `@option` — a bare literal like `#{?1,…}` is treated as a (missing) variable name and tests false.

## Detailed Design

### Right side (`status-right`)

Replace the current `status-right` assembly (roughly lines 49–68 of `tmux/tmux.conf`) with:

```tmux
set -g status-right-length 100
set -g status-left-length 100
set -g status-left ""

# Width threshold in columns: clients >= this render the FULL UI;
# narrower clients (e.g. phone over SSH) render the MINIMAL one. Drives BOTH
# the right side and the window list.
# Measure your phone once while attached:  tmux display -p '#{client_width}'
# then set this between the phone width and your PC width.
set -g @ui_full_min_width "120"

# Battery presence flag (static per host): the battery module renders only when
# real battery hardware exists. Set once at load; referenced inline below.
set -g @has_batt ""
# (upower alternative kept commented for reference)
# if-shell 'command -v upower >/dev/null && upower -e | grep -q battery' 'set -g @has_batt "1"'
if-shell '[ -d /sys/class/power_supply/BAT0 ] || ls /sys/class/power_supply/BAT* >/dev/null 2>&1' \
    'set -g @has_batt "1"'
if-shell '[ "$(uname)" = "Darwin" ] && pmset -g batt 2>/dev/null | grep -q Battery' \
    'set -g @has_batt "1"'

# Per-client status-right: rendered separately for each client, so #{client_width}
# is that client's own terminal width. Plain `set -g` (no -F) stores the #{E:...}
# tokens literally and defers all expansion to render time (after Catppuccin loads),
# exactly like the previous `-ag` modules. Modules are inlined (NOT via an
# @status_right_full indirection, which breaks cpu/battery — see Approach).
#   FULL (wide):  application | datetime | cpu | session | uptime | [battery]
#   MIN (narrow): session only
set -g status-right "#{?#{e|>=:#{client_width},#{@ui_full_min_width}},#{E:@catppuccin_status_application}#{E:@catppuccin_status_date_time}#{E:@catppuccin_status_cpu}#{E:@catppuccin_status_session}#{E:@catppuccin_status_uptime}#{?@has_batt,#{E:@catppuccin_status_battery},},#{E:@catppuccin_status_session}}"
```

Behavioral changes vs today: the multi-line `set -ag status-right` assembly (lines ~54–68) collapses into one `set -g status-right` width ternary; battery gating moves from an if-shell *append* to an if-shell *flag* (`@has_batt`) referenced inline. `status-right-length`/`status-left`/`status-left-length` are unchanged. The literal `set -g status-right ""` reset is no longer needed (the single `set -g` fully replaces the value before TPM runs).

### Left / window list

Catppuccin's `window-status-format` (inactive) and `window-status-current-format` (current) are assembled at plugin-load with the **index (`#I`) outside** the text variables, and they inline `#{@catppuccin_window_text}` / `#{@catppuccin_window_current_text}` **raw** — evaluation is deferred to render time (proven today by the live `#{b:pane_current_path}`). So no format-assembly changes are needed: only the **inactive** text variable is made width-conditional. The current-tab text is **left exactly as-is** (so the active tab keeps index + name + path + zoom in both modes).

Replace the current inactive window-text line (≈ line 46 of `tmux/tmux.conf`):

```tmux
# was: set -g @catppuccin_window_text " #W"
# Inactive tabs: name on wide clients, empty (index only) on narrow clients.
set -g @catppuccin_window_text "#{?#{e|>=:#{client_width},#{@ui_full_min_width}}, #W,}"

# UNCHANGED — current tab always shows index + name + path + zoom:
# set -g @catppuccin_window_current_text " #W #[fg=yellow]#{b:pane_current_path}#{?window_zoomed_flag, 󰍉,}"
```

Because the index lives outside `@catppuccin_window_text`, emptying the text on narrow clients leaves the index visible; inactive tabs become `1  2  3`. This line must remain **before** the TPM `run` (it already is at line 46), since Catppuccin reads it during load to build `window-status-format`.

`@catppuccin_window_current_text`, `reset.conf`, and keybindings are untouched.

### Edge case: empty inactive text cosmetics

With `basic` style + `number_position=left`, an inactive tab renders `#I` + middle-separator + `[text-style]<text>` + right-separator. When `<text>` is empty, the trailing separators (single spaces in `basic`) and the text-style color block still emit, so inactive narrow tabs are the index followed by ~1–2 spaces of padding. Acceptable; eyeballed during verification. If it looks off, the text conditional can also absorb the adjacent separator.

## Rejected Alternatives

- **B. Manual toggle keybind** — a prefix key swaps `status-right` between full/minimal. Simple, but `status-right` is session-wide, so toggling for the phone also strips the PC's bar when both are attached, and it isn't automatic. Only viable if never using both clients at once.
- **C. `client-attached` hook + `$SSH_CONNECTION`** — the "literal SSH" version. Worst fit for this topology: the option is session-wide (would change the PC's bar too), racy with simultaneous clients, and tmux cannot reliably read a *specific* client's SSH env from a format.

## Edge Cases & Notes

- **Shared-window resize:** if the phone attaches to the *same window* as the PC, tmux shrinks the shared content to the smaller client. This is unrelated to the status bar — the bar is still drawn at each client's own `client_width`, so the full/minimal split holds either way. Not addressed here.
- **Minimal-bar cosmetics:** the `session` module begins with a powerline left separator (normally connecting to the previous module). As the only module it renders as a half-separator into the session block — acceptable; eyeballed during verification.
- **Threshold overlap:** a narrow PC split (≈100 cols) will render minimal. This is the accepted trade-off ("narrow = minimal").

## Verification Plan

After editing, with no server restart required:

1. Reload: `tmux source-file ~/.tmux.conf` (the deployed symlink → `~/dotfiles/tmux/tmux.conf`). Open ≥2 windows so the tab list is meaningful.
2. **Wide — right side:** confirm the full chain renders (application | date_time | cpu | session | uptime | [battery]).
3. **Wide — tabs:** confirm every tab still shows index + name as today; the current tab also shows path + zoom flag.
4. **Narrow — right side:** check `tmux display -p '#{client_width}'`; on a client narrower than 120 (resize a terminal, or attach from the phone) confirm only the `session` module shows on the right.
5. **Narrow — tabs:** on the same narrow client, confirm inactive tabs show **index only** while the current tab still shows index + name + path; switch the active window and confirm the formerly-current tab collapses to index-only and the new current expands.
6. **Liveness:** watch the wide bar for ~1 min — the clock advances and CPU % updates (proves the inline `#{E:@catppuccin_status_*}` tokens still resolve live; if cpu shows blank/`#[fg=,bg=]` the indirection crept back in). On battery hardware, confirm the battery module still appears in the full bar; on a desktop confirm no broken battery placeholder.
7. **Boundary:** confirm a width just under 120 yields minimal (both pieces) and just over yields full — this specifically guards that `e|>=` (numeric) is used, not bare `>=` (string).

## Tuning

`@ui_full_min_width` is the single knob. Measure the phone with `tmux display -p '#{client_width}'` while attached and set the threshold between the phone width and the PC width. Default `120`.

## Rollback

Revert `tmux/tmux.conf` to the previous revision (single-file change); no plugin or state changes to undo.

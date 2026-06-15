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

Set `status-right` to a single render-time ternary on `#{client_width}` whose **full branch is the existing module chain** and whose **minimal branch is `session` only**. The non-obvious part is *how* the full chain must be assembled — a naive deferred token breaks the cpu/battery plugins (see below).

The **window list** reuses the identical per-client width branch: a one-line conditional on the inactive-tab text variable (see Detailed Design → Left / window list). Both pieces read the same `@ui_full_min_width` threshold.

### The tmux-cpu / tmux-battery substitution constraint (the crux — validated on tmux 3.4)

tmux has no native `#{cpu_percentage}` / `#{battery_*}` formats. The tmux-cpu and tmux-battery plugins implement them by a **literal string-replace on the `status-right` / `status-left` option values at load** (during `run tpm`): they scan those option values for the bare substrings `#{cpu_percentage}`, `#{cpu_fg_color}`, `#{cpu_bg_color}`, `#{battery_*}` and replace each with a `#(…script…)` command. Catppuccin's cpu/battery modules deliberately emit those bare placeholders (via `#{l:#{cpu_percentage}}`) so the plugins can find them.

**Consequence:** the bare placeholders must be physically present in the `status-right` *value* when the plugins run. Two tempting designs fail this — both observed live:

- **Deferred token** — `set -g status-right "…#{E:@catppuccin_status_cpu}…"` (no `-F`). The placeholder stays hidden inside the unexpanded token, the plugins never substitute it, and the bar renders the literal text `#{cpu_percentage}`. *(This was a regression that shipped in the first cut and was caught in live smoke testing.)*
- **`#{E:@option}` indirection** — referencing a prebuilt chain as `#{E:@status_right_full}`. The extra `#{E:}` pass at render over-expands and collapses the `#{l:}`-protected placeholders to empty (`#[fg=,bg=]`). ❌

The original (pre-change) config surfaced the placeholders by appending cpu/battery with **`-agF`** (force-expand at set time), which works on reload (when Catppuccin is loaded; note even the original does not render cpu on a truly fresh server start, only after a reload). The fix preserves that mechanism.

### Design: 3-append width ternary

Build the full chain into `@status_right_full` using the **exact per-module flags the config already used** — `-agF` for the placeholder-bearing modules (application / cpu / battery) so they force-expand and surface `#{cpu_percentage}` etc.; `-ag` for date_time / session / uptime to keep them deferred and live. Then assemble `status-right` in three appends so the placeholders surface *inside* the deferred ternary:

1. `set -g  status-right "#{?#{e|>=:#{client_width},#{@ui_full_min_width}},"` — open ternary + numeric width condition, **deferred** (no `-F`).
2. `set -agF status-right "#{@status_right_full}"` — **force-expand-insert** the full chain. `#{@…}` is a *raw* insert (not `#{E:}`), so the surfaced `#{cpu_percentage}` literals land in `status-right` verbatim — exactly what the plugins scan for — without the over-expansion the `#{E:}` indirection caused.
3. `set -ag  status-right ",#{E:@catppuccin_status_session}}"` — close with the minimal (narrow) branch, **deferred**.

tmux-cpu's replace is purely textual, so it substitutes the placeholders even though they sit inside a deferred `#{?…}`. **Verified:** the resulting full branch is *byte-identical* to the original working `status-right` after substitution, so the wide render is unchanged; narrow renders session only; `#{client_width}` stays deferred → true per-client behavior. Battery remains gated by the existing `-agF` `if-shell` append to `@status_right_full` (battery hardware only).

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

# Build the FULL chain into @status_right_full with the SAME per-module flags as
# before: -agF force-expands the placeholder-bearing modules (application/cpu/
# battery) so the tmux-cpu/tmux-battery placeholders (#{cpu_percentage}, etc.)
# surface as literal text for those plugins to string-substitute at `run tpm`;
# -ag defers date_time/session/uptime to render time (kept live).
set -g  @status_right_full ""
set -agF @status_right_full "#{E:@catppuccin_status_application}"
set -ag  @status_right_full "#{E:@catppuccin_status_date_time}"
set -agF @status_right_full "#{E:@catppuccin_status_cpu}"
set -ag  @status_right_full "#{E:@catppuccin_status_session}"
set -ag  @status_right_full "#{E:@catppuccin_status_uptime}"
# Battery appended only on battery hardware (matches prior behavior)
# (upower alternative kept commented for reference)
# if-shell 'command -v upower >/dev/null && upower -e | grep -q battery' \
#    'set -agF @status_right_full "#{E:@catppuccin_status_battery}"'
if-shell '[ -d /sys/class/power_supply/BAT0 ] || ls /sys/class/power_supply/BAT* >/dev/null 2>&1' \
    'set -agF @status_right_full "#{E:@catppuccin_status_battery}"'
if-shell '[ "$(uname)" = "Darwin" ] && pmset -g batt 2>/dev/null | grep -q Battery' \
    'set -agF @status_right_full "#{E:@catppuccin_status_battery}"'

# Per-client status-right via a deferred width ternary, in 3 appends so the FULL
# branch's #{cpu_percentage}/#{battery_*} placeholders surface in the status-right
# VALUE for tmux-cpu/battery to substitute at `run tpm`, while #{client_width}
# stays deferred to render (per client):
#   1) -ag   open ternary + numeric width condition (deferred)
#   2) -agF  insert @status_right_full's value (force-expanded -> placeholders surface)
#   3) -ag   close with the MINIMAL (narrow) branch: session only (deferred)
# Comparison MUST be #{e|>=:...} (numeric); bare #{>=:...} is a STRING compare.
#   FULL (wide):  application | datetime | cpu | session | uptime | [battery]
#   MIN  (narrow): session only
set -g  status-right "#{?#{e|>=:#{client_width},#{@ui_full_min_width}},"
set -agF status-right "#{@status_right_full}"
set -ag  status-right ",#{E:@catppuccin_status_session}}"
```

Behavioral changes vs today: the full module chain moves into `@status_right_full` (same per-module `-agF`/`-ag` flags as before, so cpu/battery placeholders still surface for the plugins), and `status-right` becomes a 3-append deferred width ternary selecting full vs. session-only. The full (wide) branch is **byte-identical** to the previous `status-right` after plugin substitution — no render change when wide. `status-right-length`/`status-left`/`status-left-length` are unchanged.

> **Why not a single inlined `set -g status-right` ternary, or an `#{E:@status_right_full}` indirection?** Both were tried and break cpu/battery — see "The tmux-cpu / tmux-battery substitution constraint" above. The 3-append form is what surfaces the bare placeholders into the `status-right` value while keeping `#{client_width}` deferred.

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
6. **Liveness (regression guard):** watch the wide bar for ~1 min — the clock advances and CPU % updates. Failure modes to watch for: literal `#{cpu_percentage}` text = the placeholder never surfaced into `status-right` (deferred-token bug); blank `#[fg=,bg=]` with no number = over-expanded (`#{E:@…}` indirection bug). Either means the 3-append construction wasn't used. On battery hardware, confirm the battery module still appears; on a desktop confirm no broken battery placeholder. (Quick check: `tmux show -gv status-right | grep -o cpu_percentage.sh` should print a hit after reload.)
7. **Boundary:** confirm a width just under 120 yields minimal (both pieces) and just over yields full — this specifically guards that `e|>=` (numeric) is used, not bare `>=` (string).

## Tuning

`@ui_full_min_width` is the single knob. Measure the phone with `tmux display -p '#{client_width}'` while attached and set the threshold between the phone width and the PC width. Default `120`.

## Rollback

Revert `tmux/tmux.conf` to the previous revision (single-file change); no plugin or state changes to undo.

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

**Consequence:** the bare placeholders must be physically present in the `status-right` *value* when the plugins run — and *separately*, the per-client width gate must wrap that value without breaking it. Three designs were tried; the first two shipped and were caught in live smoke testing:

- **Deferred token** — `set -g status-right "…#{E:@catppuccin_status_cpu}…"` (no `-F`). The placeholder stays hidden inside the unexpanded token, the plugins never substitute it, and the bar renders the literal text `#{cpu_percentage}`.
- **Force-expand the chain *inside* the ternary** (3 appends: deferred open / `-agF` insert / deferred close). This *does* surface and substitute the placeholders — but it puts the substituted chain, including Catppuccin's `#[fg=…,bg=…]` styles, directly inside `#{?cond,TRUE,FALSE}`, where the style's comma is read as the ternary separator (see below) → the entire right side renders **empty**.
- **`#{E:@option}` on an *un*-substituted chain** — the extra `#{E:}` pass over-expands and collapses the `#{l:}`-protected placeholders to empty (`#[fg=,bg=]`).

### The comma trap (validated on tmux 3.4)

Inside `#{?cond,TRUE,FALSE}`, commas split at the top level *except* when nested in `#{…}`. A comma inside a **`#[…]` style block is NOT protected**: `#{?…,#[fg=red,bg=blue]X,Y}` parses `TRUE = #[fg=red` and the bar breaks (confirmed; a literal comma can be escaped as `#,`, and nested `#{…}` tokens are safe). So a ternary branch must be a **single comma-free `#{…}` token**, never an inlined styled chain.

### Design: post-`tpm` capture + comma-free token ternary

Reconcile the two constraints by separating substitution from gating *in time*:

1. **Before `run tpm`** — build `status-right` as the plain full chain (the original `-agF`/`-ag` per-module assembly, **no** ternary). The cpu/battery placeholders surface here, so during `run tpm` the plugins string-substitute them in `status-right` (and tmux-continuum prepends its save hook).
2. **After `run tpm`** — `status-right` now holds the fully-*substituted* chain (`#(cpu_percentage.sh)`, not `#{cpu_percentage}`). Capture it into `@status_right_full`, then rebuild:
   ```tmux
   run-shell 'tmux set -g @status_right_full "$(tmux show -gqv status-right)"'
   set -g status-right "#{?#{e|>=:#{client_width},#{@ui_full_min_width}},#{E:@status_right_full},#{E:@catppuccin_status_session}}"
   ```

Both branches are single comma-free `#{E:@…}` tokens → **no comma trap**. The full token is already substituted, so `#{E:}` has no `#{l:}`-placeholder left to eat (it just re-expands stable `#(…)`/styles), and the async `#(…)` jobs still fire through the token (verified with an observable side-effect under a live attached client). `#{client_width}` stays deferred → true per-client behavior. **Verified:** the wide branch renders byte-identical to the original bar (cpu/clock/uptime live); narrow → session only.

*Tradeoff:* the captured value includes tmux-continuum's `#(continuum_save.sh)` prefix, so it lives in the full branch — auto-save runs on wide clients but not on a narrow-only phone session. Acceptable. *Fresh-start note:* like the original config, cpu only substitutes on reload (Catppuccin loads during `tpm`, after the pre-`tpm` chain is assembled), so a brand-new server renders cpu only after the first `source-file`.

### Comparison operator (validated)

Use the **numeric** comparison `#{e|>=:a,b}` — the `e|` prefix is required. Tested on tmux 3.4: bare `#{>=:80,120}` → `1` (it's a *string* compare, `"80" ≥ "120"` lexically — wrong for widths), while `#{e|>=:80,120}` → `0` (correct numeric). The man page confirms: bare `<`/`>`/`>=` are *string* comparisons; the numeric operators live under the `e|` arithmetic modifier. (Catppuccin's bare `#{==:…}` works only because string and numeric equality coincide — that does not generalize to inequalities.)

Also note: a `#{?cond,…}` condition must be a **format that evaluates to non-zero/non-empty**, e.g. `#{e|>=:…}` or a defined `@option` — a bare literal like `#{?1,…}` is treated as a (missing) variable name and tests false.

## Detailed Design

### Right side (`status-right`)

Two parts — the plain chain stays *before* `run tpm`; the width gate is applied *after* it:

```tmux
set -g status-right-length 100
set -g status-left-length 100
set -g status-left ""

# Width threshold (columns): clients >= this render the FULL UI; narrower clients
# (e.g. phone over SSH) render the MINIMAL one. Drives BOTH the right side and the
# window list.  Measure your phone:  tmux display -p '#{client_width}'
set -g @ui_full_min_width "120"

# (1) BEFORE tpm: build status-right as the plain full chain (the original
# assembly, unchanged), so tmux-cpu/battery can string-substitute their
# #{cpu_percentage}/#{battery_*} placeholders during `run tpm`. Reset first so
# tmux-continuum doesn't inherit tmux's default status-right.
# (order: application | datetime | cpu | session | uptime | battery)
set -g status-right ""
set -agF status-right "#{E:@catppuccin_status_application}"
set -ag  status-right "#{E:@catppuccin_status_date_time}"
set -agF status-right "#{E:@catppuccin_status_cpu}"
set -ag  status-right "#{E:@catppuccin_status_session}"
set -ag  status-right "#{E:@catppuccin_status_uptime}"
# (upower alternative kept commented for reference)
# if-shell 'command -v upower >/dev/null && upower -e | grep -q battery' \
#    'set -agF status-right "#{E:@catppuccin_status_battery}"'
if-shell '[ -d /sys/class/power_supply/BAT0 ] || ls /sys/class/power_supply/BAT* >/dev/null 2>&1' \
    'set -agF status-right "#{E:@catppuccin_status_battery}"'
if-shell '[ "$(uname)" = "Darwin" ] && pmset -g batt 2>/dev/null | grep -q Battery' \
    'set -agF status-right "#{E:@catppuccin_status_battery}"'

run '~/.tmux/plugins/tpm/tpm'

# (2) AFTER tpm: status-right is now the fully-substituted chain (#(cpu_percentage.sh),
# etc.). Capture it into @status_right_full, then wrap in the per-client width ternary
# with comma-free #{E:@...} token branches (an inlined #[fg=,bg=] comma would be read
# as the ternary separator and break the bar). Comparison is numeric (#{e|>=:...}).
#   FULL (wide):   @status_right_full   MIN (narrow): session only
run-shell 'tmux set -g @status_right_full "$(tmux show -gqv status-right)"'
set -g status-right "#{?#{e|>=:#{client_width},#{@ui_full_min_width}},#{E:@status_right_full},#{E:@catppuccin_status_session}}"
```

Behavioral changes vs today: the pre-`tpm` `status-right` assembly is unchanged (so cpu/battery substitution is identical); two lines are added after `run tpm` to capture the substituted chain and wrap it in the width ternary. The full (wide) branch is **byte-identical** to the previous `status-right`, so there is no render change when wide. `status-right-length`/`status-left`/`status-left-length` unchanged.

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
6. **Liveness (regression guard):** watch the wide bar for ~1 min — the clock advances and CPU % updates. Failure modes to watch for: literal `#{cpu_percentage}` text = the placeholder never surfaced into `status-right` (deferred-token bug); blank `#[fg=,bg=]` with no number = over-expanded (`#{E:@…}`-on-unsubstituted bug); **entire right side empty** = a `#[fg=,bg=]` style comma broke the `#{?…}` ternary (the chain was inlined instead of referenced as a token). On battery hardware, confirm the battery module still appears; on a desktop confirm no broken battery placeholder. (Quick checks after reload: `tmux show -gv @status_right_full | grep -o cpu_percentage.sh` prints a hit, and `tmux show -gv status-right` is the comma-free token ternary `#{?…,#{E:@status_right_full},#{E:@catppuccin_status_session}}`.)
7. **Boundary:** confirm a width just under 120 yields minimal (both pieces) and just over yields full — this specifically guards that `e|>=` (numeric) is used, not bare `>=` (string).

## Tuning

`@ui_full_min_width` is the single knob. Measure the phone with `tmux display -p '#{client_width}'` while attached and set the threshold between the phone width and the PC width. Default `120`.

## Rollback

Revert `tmux/tmux.conf` to the previous revision (single-file change); no plugin or state changes to undo.

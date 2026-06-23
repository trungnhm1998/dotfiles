# Dynamic Workspaces on yabai (SketchyBar) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the SketchyBar workspace strip dynamic on yabai — show only spaces that have ≥1 window or are focused, hiding the rest — so it feels like i3/sway dynamic workspaces with zero runtime space create/destroy.

**Architecture:** A single SketchyBar "broker" item (`spaces_controller`) runs one plugin (`spaces.sh`) on every relevant event; the plugin does one `yabai -m query --spaces` and batch-sets each per-space item's `drawing`. SketchyBar's own events (`space_change`, `front_app_switched`, `display_change`) plus new yabai `window_created`/`window_destroyed` signals drive it. yabai is the single source of truth.

**Tech Stack:** bash, `jq`, yabai (`-m query`/`-m signal`), SketchyBar (`--add item/event`, `--set`, `--subscribe`, `--trigger`, `--query`).

## Global Constraints

- **Platform:** macOS only. Edit **only** `.config/sketchybar/*` and `.config/yabai/yabairc`. Do **not** touch skhd, jankyborders, window rules, or the SIP scripting addition (`yabai --load-sa`).
- **Zero runtime `space --create` / `space --destroy`.** (Grep-verified in Task 2.)
- **Drawing rule (exact):** a space item is `drawing=on` iff `has-focus == true` **OR** `(.windows | length) > 0`; the focused space also gets `background.drawing=on`. Otherwise `drawing=off`.
- **Plain items, not the native `space` component.** Items are named `space.<index>`. yabai is the source of truth for focus + occupancy.
- **One controller:** `spaces.sh` does **one** `yabai -m query --spaces` per invocation and batches all `--set`s into a single `sketchybar` call.
- **Occupied = ≥1 window of any kind** (managed or floating).
- **Plugin PATH:** every plugin sets `export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"`.
- **Symlinked configs:** `~/.config/sketchybar` → `…/dotfiles/.config/sketchybar/`, `~/.config/yabai` → `…/dotfiles/.config/yabai`. Editing repo files updates the live config; apply with `sketchybar --reload` / `yabai --restart-service`.
- **Commits:** conventional-commit style, **no** AI-attribution / `Co-Authored-By` footers.
- **Rollback:** `git checkout -- <file> && sketchybar --reload` (or `yabai --restart-service`).
- All commands below run from the repo root: `/Users/trungnhm1998/dotfiles`.

---

### Task 1: Dynamic workspace strip (controller plugin + `sketchybarrc` rewrite)

**Files:**
- Create: `.config/sketchybar/plugins/spaces.sh`
- Modify: `.config/sketchybar/sketchybarrc` (replace lines 43-82 — the `Adding Mission Control Space Indicators` section through the commented-out `SPACE_ICONS` block)
- Delete: `.config/sketchybar/plugins/space.sh` (superseded)

**Interfaces:**
- Produces:
  - Per-space plain items named `space.<index>` (one per space in the pool), each with `click_script="yabai -m space --focus <index>"`.
  - A broker item `spaces_controller` (`drawing=off updates=on`) whose `script` is `spaces.sh`, subscribed to `yabai_windows_changed space_change front_app_switched display_change`.
  - A custom event `yabai_windows_changed`.
  - `spaces.sh`: on each run, reads `yabai -m query --spaces` and for every space sets `space.<index>` → `drawing` = `on` iff `has-focus` or `windows>0` else `off`, and `background.drawing` = the `has-focus` value (`true`/`false`).
- Consumes: yabai `-m query --spaces`; SketchyBar native events. (yabai `window_*` triggers come in Task 2.)

- [ ] **Step 1: Capture the baseline (the "failing" state)**

Confirm the strip is currently static — every space item is drawn, including empty ones.

```bash
# List spaces that are empty AND unfocused (these SHOULD become hidden):
yabai -m query --spaces | jq -r '.[] | select((.windows|length)==0 and (.["has-focus"]|not)) | .index'
# Drawing state of one such empty space (pick an index the line above printed, e.g. 6):
sketchybar --query space.6 | jq -r '.geometry.drawing'
```
Expected now: the first command prints one or more indices (empty spaces); the second prints `on` (bug — empty space is drawn).

- [ ] **Step 2: Create the controller plugin `spaces.sh`**

Create `.config/sketchybar/plugins/spaces.sh`:

```bash
#!/bin/bash
# Dynamic workspace strip for yabai: one query per event; show a space iff it
# has >=1 window OR is focused. Driven by yabai signals + SketchyBar
# space/app/display events. yabai is the source of truth.
# Spec: docs/superpowers/specs/2026-06-24-yabai-dynamic-workspaces-design.md
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

args=()
while read -r idx focus nwin; do
  if [[ "$focus" == "true" || "$nwin" -gt 0 ]]; then
    draw="on"
  else
    draw="off"
  fi
  args+=(--set "space.$idx" drawing="$draw" background.drawing="$focus")
done < <(yabai -m query --spaces | jq -r '.[] | "\(.index) \(.["has-focus"]) \(.windows | length)"')

[[ ${#args[@]} -gt 0 ]] && sketchybar "${args[@]}"
```

- [ ] **Step 3: Make it executable and syntax-check it**

Run:
```bash
chmod +x .config/sketchybar/plugins/spaces.sh
bash -n .config/sketchybar/plugins/spaces.sh && echo "syntax OK"
```
Expected: `syntax OK` (no errors).

- [ ] **Step 4: Rewrite the space block in `sketchybarrc`**

Open `.config/sketchybar/sketchybarrc`. **Replace lines 43-82** (from the comment `##### Adding Mission Control Space Indicators #####` through the final line of the commented-out `SPACE_ICONS` loop, i.e. the line `# done` at 82) with:

```bash
##### Dynamic workspace indicators (yabai) #####
# Show a space iff it has >=1 window OR is focused; spaces.sh recomputes on each
# event. yabai is the source of truth — plain items, not the native `space`
# component. Spec: docs/superpowers/specs/2026-06-24-yabai-dynamic-workspaces-design.md
sketchybar --add event yabai_windows_changed

for sid in $( yabai -m query --spaces | jq -r '.[].index' ); do
  space=(
    icon="$sid"
    icon.padding_left=7
    icon.padding_right=7
    background.color=0x40ffffff
    background.corner_radius=5
    background.height=25
    background.drawing=off
    label.drawing=off
    drawing=off
    click_script="yabai -m space --focus $sid"
  )
  sketchybar --add item space."$sid" left --set space."$sid" "${space[@]}"
done

# Invisible broker: reacts to events, drives every space item via spaces.sh.
# updates=on forces its script to run even though it is not drawn.
sketchybar --add item spaces_controller left \
           --set spaces_controller drawing=off updates=on script="$PLUGIN_DIR/spaces.sh" \
           --subscribe spaces_controller yabai_windows_changed space_change \
                       front_app_switched display_change

sketchybar --trigger yabai_windows_changed   # initial paint
```

Note: `PLUGIN_DIR` is already defined at `sketchybarrc:22` (`PLUGIN_DIR="$CONFIG_DIR/plugins"`), so `$PLUGIN_DIR` resolves here. Leave everything outside 43-82 untouched.

- [ ] **Step 5: Syntax-check `sketchybarrc`**

Run:
```bash
bash -n .config/sketchybar/sketchybarrc && echo "syntax OK"
```
Expected: `syntax OK`.

- [ ] **Step 6: Remove the superseded `space.sh`**

Run:
```bash
git rm .config/sketchybar/plugins/space.sh
```
Expected: `rm '.config/sketchybar/plugins/space.sh'`. (Nothing references it after Step 4.)

- [ ] **Step 7: Reload SketchyBar**

Run:
```bash
sketchybar --reload
```
Expected: no error; the strip repaints. (This re-runs `sketchybarrc` from scratch — atomic.)

- [ ] **Step 8: Verify the drawing rule holds for every space (the "passing" test)**

Run this checker — it compares each space's expected vs actual drawing state:
```bash
for i in $(yabai -m query --spaces | jq -r '.[].index'); do
  want=$(yabai -m query --spaces | jq -r ".[] | select(.index==$i) | if ((.windows|length)>0 or .[\"has-focus\"]) then \"on\" else \"off\" end")
  got=$(sketchybar --query space.$i | jq -r '.geometry.drawing')
  printf "space %s want=%s got=%s %s\n" "$i" "$want" "$got" "$([ "$want" = "$got" ] && echo OK || echo MISMATCH)"
done
```
Expected: every line ends in `OK` — occupied/focused spaces `on`, empty unfocused spaces `off`.

- [ ] **Step 9: Verify focus reactivity (controller correctness + live event)**

Programmatic (force a recompute, no timing race):
```bash
E=$(yabai -m query --spaces | jq -r '.[] | select((.windows|length)==0 and (.["has-focus"]|not)) | .index' | head -1)
echo "empty space picked: $E"
sketchybar --query space.$E | jq -r '.geometry.drawing'      # off
yabai -m space --focus "$E"
sketchybar --trigger yabai_windows_changed
sketchybar --query space.$E | jq -r '.geometry.drawing'      # on  (focused-empty rule)
```
Expected: `off` then `on`.

Live event (visual): switch spaces with `alt+1` … `alt+9` and watch the strip — only occupied + the current space appear, and the highlight follows you **without** running the trigger manually. (If no empty space exists, skip — every space is shown, which is correct.)

- [ ] **Step 10: Commit**

```bash
git add .config/sketchybar/plugins/spaces.sh .config/sketchybar/sketchybarrc
git commit -m "feat(sketchybar): dynamic workspace strip (show only occupied/focused spaces)"
```

---

### Task 2: Live window reactivity via yabai signals

**Files:**
- Modify: `.config/yabai/yabairc` (append two signals after the existing signal block, around line 84, before the final `sketchybar --reload` line at 85)

**Interfaces:**
- Consumes: the `yabai_windows_changed` event and `spaces_controller` from Task 1.
- Produces: yabai `window_created` and `window_destroyed` signals whose action is `sketchybar --trigger yabai_windows_changed`, so opening/closing a window updates the strip **without** a space switch. (Space/display changes are already covered by Task 1's native `space_change`/`display_change` subscriptions; window-focus-following moves via `shift+alt+N` are covered by `space_change`.)

- [ ] **Step 1: Show the gap (the "failing" test)**

With only Task 1 in place, a window event on a **non-focused** space does not update the strip until the next space switch. Demonstrate:
```bash
# Put a window on a currently-empty space, then leave that space:
E=$(yabai -m query --spaces | jq -r '.[] | select((.windows|length)==0 and (.["has-focus"]|not)) | .index' | head -1)
yabai -m space --focus "$E"
open -na "TextEdit"                 # new window lands on space E
yabai -m space --focus 1            # leave E (E now occupied+unfocused → shown)
sketchybar --query space.$E | jq -r '.geometry.drawing'   # on (correct so far)
osascript -e 'quit app "TextEdit"'  # destroy E's window from afar (no space switch)
sketchybar --query space.$E | jq -r '.geometry.drawing'   # STILL on  ← stale (the bug)
```
Expected: the last query prints `on` even though space `E` is now empty and unfocused — stale, because no `window_destroyed` trigger exists yet. (Note `E` for Step 4.)

- [ ] **Step 2: Add the window signals to `yabairc`**

Open `.config/yabai/yabairc`. **After** the existing `window_destroyed` signal (line 79) and before the display/reload block (lines 82-85), insert:

```bash
# Dynamic workspace strip: re-evaluate which spaces the bar shows whenever a
# window appears or disappears (space/display changes are handled by SketchyBar's
# own events). The spaces.sh controller does the work.
# Spec: docs/superpowers/specs/2026-06-24-yabai-dynamic-workspaces-design.md
yabai -m signal --add event=window_created   action="sketchybar --trigger yabai_windows_changed"
yabai -m signal --add event=window_destroyed action="sketchybar --trigger yabai_windows_changed"
```

These are **additive** — yabai supports multiple handlers per event, so the existing `window_destroyed` → `focus-window-on-destroy.sh` signal (line 79) keeps working alongside this one.

- [ ] **Step 3: Syntax-check and restart yabai**

Run:
```bash
bash -n .config/yabai/yabairc && echo "syntax OK"
yabai --restart-service
```
Expected: `syntax OK`, then yabai restarts (the strip repaints via the `sketchybar --reload` at the end of `yabairc`).

- [ ] **Step 4: Verify window reactivity (the "passing" test)**

Repeat the Step 1 scenario; now the destroy updates the strip with no space switch:
```bash
E=$(yabai -m query --spaces | jq -r '.[] | select((.windows|length)==0 and (.["has-focus"]|not)) | .index' | head -1)
yabai -m space --focus "$E"
open -na "TextEdit"
sketchybar --query space.$E | jq -r '.geometry.drawing'   # on (window_created fired, while focused anyway)
yabai -m space --focus 1
osascript -e 'quit app "TextEdit"'                        # window_destroyed fires
sketchybar --query space.$E | jq -r '.geometry.drawing'   # off  ← now updates without a switch
```
Expected: final query prints `off`. (If it races, re-run the final query once — the event is near-instant.)

- [ ] **Step 5: Verify no runtime space churn (Global Constraint)**

Run:
```bash
grep -rEn 'space --(create|destroy)' .config/sketchybar .config/yabai && echo "FOUND (bad)" || echo "none — OK"
```
Expected: `none — OK`.

- [ ] **Step 6: Full acceptance sweep**

- `alt+1`…`alt+9`: only occupied + current space show; highlight follows. ✅
- Open an app on an empty space → its number appears. ✅
- Close the last window on a space and switch away → its number disappears. ✅
- The space you are currently on always shows (even if empty). ✅
- `shift+alt+N` (move window + follow focus): source space hides if it empties, destination shows. ✅

- [ ] **Step 7: Commit**

```bash
git add .config/yabai/yabairc
git commit -m "feat(yabai): trigger sketchybar workspace strip on window create/destroy"
```

---

## Notes / known limitations (from the spec)

- **Move-without-focus is the one uncovered path:** moving a window to another space *without* following focus (not a default skhd binding — `shift+alt+N` always follows focus) won't update the strip until the next event. Acceptable; documented in the spec's risks.
- **Floating windows count as occupied** (Global Constraint / spec D8): a lone `manage=off` utility keeps its space visible. Switch the `jq` to managed-only later if undesired.
- **Multi-display:** single-display today. When an external monitor is attached, the `external_bar` config must run the same controller logic for its display — out of scope here, tracked in the spec.

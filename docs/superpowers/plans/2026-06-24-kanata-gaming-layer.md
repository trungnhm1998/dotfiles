# Kanata Gaming Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an instant-keys "gaming" layer to the MacBook built-in keyboard's kanata config, with an `Fn+G` (and clickable SketchyBar) WORK↔GAME toggle and toast + status-bar feedback.

**Architecture:** A new identity `deflayer gaming` maps every home-row-mod / layer-hold key to its literal self (zero tap-hold timing); `Fn+G` flips the persistent base layer via `layer-switch`, made symmetric by a `funcs-game` twin layer. kanata's built-in TCP server (`--port 10000`, stock Homebrew binary) streams `LayerChange` events to a user LaunchAgent listener that drives a `terminal-notifier` toast, a state file, and a SketchyBar indicator that is itself a clickable toggle (pushes `ChangeLayer` back over TCP).

**Tech Stack:** kanata 1.11.0 (Lisp-like `.kbd` config), macOS `launchd` (root LaunchDaemon for kanata + user LaunchAgent for the listener), bash (`/dev/tcp`, `nc`, `jq`), SketchyBar, terminal-notifier.

## Global Constraints

_Every task's requirements implicitly include this section. Values copied from the spec._

- **Platform:** macOS only, MacBook **built-in** keyboard (`~/.config/kanata/kanata.kbd`). External Voyager is untouched / out of scope.
- **Binary:** stock **Homebrew kanata 1.11.0**. The TCP server is a default feature. Do **NOT** use the `(cmd …)` action, `danger-enable-cmd`, or a `cmd_allowed` build.
- **launchd split:** kanata runs as a **root LaunchDaemon** (`/Library/LaunchDaemons/dev.kanata.kanata.plist`, copied + `sed`-substituted, not symlinked). The listener runs as a **user LaunchAgent**. Never merge these.
- **`base` MUST stay the first `deflayer`** — it is the boot layer and the restart-bailout.
- **TCP bind:** bare `--port 10000` → loopback `127.0.0.1:10000` only.
- **PATH in scripts:** every new shell script MUST `export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"` (LaunchAgent & SketchyBar contexts have a minimal PATH). Brew tools live at `/opt/homebrew/bin`; `nc` at `/usr/bin/nc`.
- **Identity-layer rule:** in `gaming`, a neutralized key is a **literal keycode** (instant). `_` (transparent) only for keys we deliberately inherit — never for the home-row-mod keys.
- **Script linting:** `shellcheck` is **not** on PATH (Mason-only). Validate scripts with `bash -n`.
- **Listener filtering:** reflect only the persistent states `gaming`/`base`; de-dupe; ignore transient `nav`/`funcs`/`funcs-game`.
- **Git:** one commit per task on `master`. **No** `Co-Authored-By` or AI-attribution trailers.

**Reference:** spec `docs/superpowers/specs/2026-06-24-kanata-gaming-layer-design.md` (commit `f426b29`).

---

### Task 1: kanata keymap — gaming layer + `Fn+G` toggle

Self-contained: after this task `Fn+G` flips WORK↔GAME and every key is instant in GAME — testable by feel, before any feedback wiring exists.

**Files:**
- Modify: `.config/kanata/kanata.kbd` (`defsrc`, `defalias`, `base`, `nav`, `funcs`; add `gaming` + `funcs-game`)

**Interfaces:**
- Produces: layers `gaming`, `funcs-game`; aliases `@game-on` = `(layer-switch gaming)`, `@game-off` = `(layer-switch base)`, `@fnl-game` = `(multi fn (layer-while-held funcs-game))`. Layer names `gaming` / `base` are the exact strings later tasks send/receive over TCP.

- [ ] **Step 1: Add `g` to `defsrc`**

Replace:
```lisp
  a    s    d    f    j    k    l    ;
```
with (inserts `g` between `f` and `j`):
```lisp
  a    s    d    f    g    j    k    l    ;
```

- [ ] **Step 2: Add the toggle aliases to `defalias`**

Inside the existing `(defalias …)` block, before its closing `)` (right after the `fnl` alias), add:
```lisp
  ;; --- Gaming layer toggle (Fn+G) ---
  game-on   (layer-switch gaming)                    ;; WORK → GAME
  game-off  (layer-switch base)                       ;; GAME → WORK
  fnl-game  (multi fn (layer-while-held funcs-game))  ;; Fn in GAME → exit-aware funcs
```

- [ ] **Step 3: Add the `g` slot to `base`, `nav`, `funcs`**

In `(deflayer base …)` replace:
```lisp
  @a   @s   @d   @f   @j   @k   @l   @scln
```
with:
```lisp
  @a   @s   @d   @f   g    @j   @k   @l   @scln
```

In `(deflayer nav …)` replace:
```lisp
  lctl lsft lalt lmet down up   rght _
```
with:
```lisp
  lctl lsft lalt lmet _    down up   rght _
```

In `(deflayer funcs …)` replace its home-row line (the line of eight underscores between the single `_` caps line and the four-underscore `z`-row line):
```lisp
  _    _    _    _    _    _    _    _
```
with:
```lisp
  _    _    _    _    @game-on _    _    _    _
```

- [ ] **Step 4: Append the `gaming` and `funcs-game` layers**

At the **end** of the file (after `(deflayer funcs …)`), add:
```lisp
;; Gaming layer: every neutralized key is a LITERAL keycode (instant) — never
;; transparent `_`, which would fall through to base and re-import the home-row
;; mods. `_` is used only for keys we deliberately inherit (F-row, h/y/u/i/o).
;; Fn → funcs-game (so Fn+G exits); ralt keeps Hyper for window management.
(deflayer gaming
  _    _    _    _    _    _    _    _    _    _    _    _
  esc
  a    s    d    f    g    j    k    l    ;
  z    x    .    /
  @fnl-game  @hyp
  spc  _    _    _    _    _
)

;; Fn twin for GAME mode: identical to `funcs` except G exits to WORK.
(deflayer funcs-game
  brdn brup mctl sls  dtn  dnd  prev pp   next mute vold volu
  _
  _    _    _    _    @game-off _    _    _    _
  _    _    _    _
  _    _
  _    _    _    _    _    _
)
```

- [ ] **Step 5: Validate the config compiles**

Run:
```bash
kanata --cfg "$HOME/.config/kanata/kanata.kbd" --check -q && echo "CONFIG OK"
```
Expected: `CONFIG OK` (exit 0). If it errors, the message names the bad layer/token — fix before continuing. Common cause: a `deflayer` whose token count ≠ `defsrc` (must be **9** on the home-row line now).

- [ ] **Step 6: Apply to the running daemon**

Run:
```bash
bash scripts/kanata-reload.sh
```
Expected: `kanata reloaded.` (re-validates, then `sudo launchctl kickstart -k system/dev.kanata.kanata`; will prompt for sudo).

- [ ] **Step 7: Behaviour test the toggle**

In any text field:
1. Press **Fn+G** (hold Fn, tap G, release) → you are now in GAME (no feedback yet — that's later tasks).
2. Hold **`a`** ~1s → expect repeating `aaaa…` (NOT Ctrl). Hold **Space** ~1s → repeating spaces (NOT nav arrows). Type **`asdf`** fast → `asdf` (no modifiers).
3. Press **Fn+G** again → back to WORK.
4. In WORK, hold **`a`** + tap **`x`** → expect `Ctrl+X` behaviour (home-row mod restored), confirming only GAME is neutralized.

Expected: keys are instant in GAME, home-row mods intact in WORK.

- [ ] **Step 8: Commit**

```bash
git add .config/kanata/kanata.kbd
git commit -m "feat(kanata): gaming layer + Fn+G WORK/GAME toggle"
```

---

### Task 2: Enable kanata's TCP server (`--port 10000`)

**Files:**
- Modify: `.config/kanata/dev.kanata.kanata.plist` (add `--port 10000` to `ProgramArguments`)

**Interfaces:**
- Produces: a loopback TCP server at `127.0.0.1:10000` that pushes `{"LayerChange":{"new":"<layer>"}}` (newline-terminated JSON) on every layer change and answers `{"RequestCurrentLayerName":{}}` → `{"CurrentLayerName":{"name":"<layer>"}}` and `{"ChangeLayer":{"new":"<layer>"}}` commands. Consumed by Tasks 3 and 4.

- [ ] **Step 1: Add the port flag to the plist source**

In `.config/kanata/dev.kanata.kanata.plist`, replace:
```xml
    <string>__KANATA__</string>
    <string>--no-wait</string>
    <string>--cfg</string>
```
with:
```xml
    <string>__KANATA__</string>
    <string>--no-wait</string>
    <string>--port</string>
    <string>10000</string>
    <string>--cfg</string>
```

- [ ] **Step 2: Validate the plist**

Run:
```bash
plutil -lint .config/kanata/dev.kanata.kanata.plist
```
Expected: `…dev.kanata.kanata.plist: OK`.

- [ ] **Step 3: Re-deploy the live daemon plist (sudo)**

The live daemon is a **copy** in `/Library/LaunchDaemons`, so editing the source isn't enough — re-copy, re-substitute placeholders, and re-bootstrap:
```bash
sudo launchctl bootout system/dev.kanata.kanata 2>/dev/null
sudo cp ~/.config/kanata/dev.kanata.kanata.plist /Library/LaunchDaemons/dev.kanata.kanata.plist
sudo sed -i '' "s|__KANATA__|$(which kanata)|; s|__USER__|$USER|" /Library/LaunchDaemons/dev.kanata.kanata.plist
sudo chown root:wheel /Library/LaunchDaemons/dev.kanata.kanata.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist
```
Expected: no errors. (Keyboard remap keeps working.)

- [ ] **Step 4: Verify the port responds**

Run:
```bash
printf '{"RequestCurrentLayerName":{}}\n' | nc -w1 127.0.0.1 10000
```
Expected: a JSON line such as `{"CurrentLayerName":{"name":"base"}}` (or another `LayerNames`/layer reply). If you get nothing, check `/tmp/kanata.err.log` and that Step 3's bootstrap succeeded.

- [ ] **Step 5: Commit**

```bash
git add .config/kanata/dev.kanata.kanata.plist
git commit -m "feat(kanata): enable loopback TCP server on :10000"
```

---

### Task 3: Layer listener — toast + state file (user LaunchAgent)

**Files:**
- Create: `.config/kanata/kanata-layer-listener.sh`
- Create: `.config/kanata/dev.kanata.layer-listener.plist`
- Modify: `setup_mac.sh` (document loading the listener agent)

**Interfaces:**
- Consumes: TCP `LayerChange` / `CurrentLayerName` from Task 2.
- Produces: state file `~/.cache/kanata/layer` containing `gaming` or `base`; a `terminal-notifier` toast per switch; calls `sketchybar --set kanata_mode label=…` (a no-op until Task 4 adds the item). Consumed by Task 4's click handler (reads the state file).

- [ ] **Step 1: Create the listener script**

Create `.config/kanata/kanata-layer-listener.sh`:
```bash
#!/bin/bash
# kanata-layer-listener.sh — subscribe to kanata's TCP layer-change stream and
# reflect the persistent WORK/GAME mode via SketchyBar + a terminal-notifier toast.
# Runs as a USER LaunchAgent (needs the Aqua session). LaunchAgents get a minimal
# PATH, so set it explicitly for the brew tools.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
set -u

PORT="${KANATA_PORT:-10000}"
STATE="$HOME/.cache/kanata/layer"
mkdir -p "$(dirname "$STATE")"
last=""

render() {                       # $1 = gaming | base
  case "$1" in
    gaming) icon="🎮"; word="GAME" ;;
    base)   icon="⌨️";  word="WORK" ;;
    *) return ;;
  esac
  printf '%s' "$1" > "$STATE"
  sketchybar --set kanata_mode label="$icon $word" 2>/dev/null
  terminal-notifier -title "kanata" -message "$icon $word mode" -group kanata-mode 2>/dev/null
}

while true; do
  if exec 3<>"/dev/tcp/127.0.0.1/$PORT" 2>/dev/null; then
    printf '{"RequestCurrentLayerName":{}}\n' >&3            # seed current state on connect
    while IFS= read -r line <&3; do
      layer=$(printf '%s' "$line" | jq -r '.LayerChange.new // .CurrentLayerName.name // empty' 2>/dev/null)
      case "$layer" in
        gaming|base) ;;          # persistent states we reflect
        *) continue ;;           # ignore transient nav/funcs/funcs-game + parse misses
      esac
      [ "$layer" = "$last" ] && continue
      last="$layer"
      render "$layer"
    done
    exec 3<&- 3>&-               # connection dropped (kanata restarted)
  fi
  last=""                        # force a re-render after reconnect
  sleep 1
done
```

- [ ] **Step 2: Make it executable and syntax-check it**

```bash
chmod +x .config/kanata/kanata-layer-listener.sh
bash -n .config/kanata/kanata-layer-listener.sh && echo "SYNTAX OK"
```
Expected: `SYNTAX OK` (no other output).

- [ ] **Step 3: Unit-smoke the JSON parsing**

```bash
echo '{"LayerChange":{"new":"gaming"}}'      | jq -r '.LayerChange.new // .CurrentLayerName.name // empty'
echo '{"CurrentLayerName":{"name":"base"}}'  | jq -r '.LayerChange.new // .CurrentLayerName.name // empty'
echo '{"LayerChange":{"new":"nav"}}'         | jq -r '.LayerChange.new // .CurrentLayerName.name // empty'
```
Expected output, one per line:
```
gaming
base
nav
```
(The first two are reflected; `nav` is dropped by the `case` filter.)

- [ ] **Step 4: Create the listener LaunchAgent plist**

Create `.config/kanata/dev.kanata.layer-listener.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.kanata.layer-listener</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/__USER__/.config/kanata/kanata-layer-listener.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/kanata-listener.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/kanata-listener.err.log</string>
</dict>
</plist>
```

- [ ] **Step 5: Validate the plist**

```bash
plutil -lint .config/kanata/dev.kanata.layer-listener.plist
```
Expected: `…dev.kanata.layer-listener.plist: OK`.

- [ ] **Step 6: Load the listener as a user agent**

```bash
mkdir -p ~/.cache/kanata
cp ~/.config/kanata/dev.kanata.layer-listener.plist ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
sed -i '' "s|__USER__|$USER|" ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
launchctl bootout gui/$(id -u)/dev.kanata.layer-listener 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
```
Expected: no errors. Confirm it's alive:
```bash
launchctl print gui/$(id -u)/dev.kanata.layer-listener | grep -E 'state|pid'
```
Expected: shows `state = running`.

- [ ] **Step 7: Verify toast + state file on toggle**

Press **Fn+G** → a toast `🎮 GAME mode` appears; then:
```bash
cat ~/.cache/kanata/layer; echo
```
Expected: `gaming`. Press **Fn+G** again → toast `⌨️ WORK mode`; file now reads `base`.

- [ ] **Step 8: Document the listener in `setup_mac.sh`**

In `setup_mac.sh`, immediately **after** the existing kanata block (after the `echo "NOTE: kanata installed …"` line at ~`:120`), add:
```bash
# --- kanata layer indicator (WORK/GAME toast + SketchyBar) ---
# Needs --port in dev.kanata.kanata.plist (already included). One-time user agent:
#   mkdir -p ~/.cache/kanata
#   cp ~/.config/kanata/dev.kanata.layer-listener.plist ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
#   sed -i '' "s|__USER__|$USER|" ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
#   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
# Reload after editing the listener: launchctl bootout gui/$(id -u)/dev.kanata.layer-listener && \
#   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.kanata.layer-listener.plist
```

- [ ] **Step 9: Commit**

```bash
git add .config/kanata/kanata-layer-listener.sh .config/kanata/dev.kanata.layer-listener.plist setup_mac.sh
git commit -m "feat(kanata): WORK/GAME layer listener — toast + state file"
```

---

### Task 4: SketchyBar indicator + clickable toggle

**Files:**
- Create: `.config/sketchybar/plugins/kanata_mode.sh`
- Modify: `.config/sketchybar/sketchybarrc` (add the `kanata_mode` item before `sketchybar --update`)

**Interfaces:**
- Consumes: state file `~/.cache/kanata/layer` (Task 3) for the click/render decision; TCP port (Task 2) to push `ChangeLayer`. The listener (Task 3) drives this item's label live via `sketchybar --set kanata_mode`.
- Produces: a right-side `kanata_mode` item; clicking it flips the mode.

- [ ] **Step 1: Create the SketchyBar plugin**

Create `.config/sketchybar/plugins/kanata_mode.sh`:
```bash
#!/bin/bash
# kanata_mode.sh — SketchyBar item for the kanata WORK/GAME indicator.
#   mouse.clicked → flip kanata's base layer over its TCP port.
#   any other run (initial/forced) → render the label from the state file.
# The listener drives live updates via `sketchybar --set`; this handles clicks + init.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
STATE="$HOME/.cache/kanata/layer"
PORT="${KANATA_PORT:-10000}"

render() {
  cur=$(cat "$STATE" 2>/dev/null)
  if [ "$cur" = "gaming" ]; then
    sketchybar --set "$NAME" label="🎮 GAME"
  else
    sketchybar --set "$NAME" label="⌨️ WORK"
  fi
}

case "$SENDER" in
  mouse.clicked)
    cur=$(cat "$STATE" 2>/dev/null)
    [ "$cur" = "gaming" ] && next="base" || next="gaming"
    printf '{"ChangeLayer":{"new":"%s"}}\n' "$next" | nc -w1 127.0.0.1 "$PORT"
    ;;
  *)
    render
    ;;
esac
```

- [ ] **Step 2: Make it executable and syntax-check it**

```bash
chmod +x .config/sketchybar/plugins/kanata_mode.sh
bash -n .config/sketchybar/plugins/kanata_mode.sh && echo "SYNTAX OK"
```
Expected: `SYNTAX OK`.

- [ ] **Step 3: Unit-smoke the toggle decision**

```bash
S=$(mktemp); echo gaming > "$S"; cur=$(cat "$S"); [ "$cur" = "gaming" ] && echo base || echo gaming
echo base    > "$S"; cur=$(cat "$S"); [ "$cur" = "gaming" ] && echo base || echo gaming
rm -f "$S"
```
Expected:
```
base
gaming
```

- [ ] **Step 4: Add the item to `sketchybarrc`**

In `.config/sketchybar/sketchybarrc`, immediately **before** the line:
```bash
##### Force all scripts to run the first time (never do this in a script) #####
sketchybar --update
```
insert:
```bash
##### kanata WORK/GAME mode indicator (clickable toggle) #####
sketchybar --add item kanata_mode right \
           --set kanata_mode icon.drawing=off label="⌨️ WORK" \
                 script="$PLUGIN_DIR/kanata_mode.sh" \
           --subscribe kanata_mode mouse.clicked

```

- [ ] **Step 5: Reload SketchyBar**

```bash
sketchybar --reload
```
Expected: bar reloads; a `⌨️ WORK` / `🎮 GAME` item appears on the right reflecting the current state (the listener also `--set`s it on the next change).

- [ ] **Step 6: End-to-end verification**

1. Observe the `kanata_mode` item — it shows the current mode.
2. **Click** the item → mode flips, a toast fires, and the label updates (click → TCP `ChangeLayer` → kanata → `LayerChange` → listener → toast + `--set`).
3. Press **Fn+G** → the same item's label tracks the keypress too.
4. Confirm interchangeability: click to GAME, then `Fn+G` to WORK — both land correctly and the bar agrees.

Expected: indicator and toast stay in sync across keypress and click; `cat ~/.cache/kanata/layer` matches the displayed mode.

- [ ] **Step 7: Commit**

```bash
git add .config/sketchybar/plugins/kanata_mode.sh .config/sketchybar/sketchybarrc
git commit -m "feat(sketchybar): clickable kanata WORK/GAME indicator"
```

---

## Self-Review

**1. Spec coverage:**
- D1 `layer-switch` not `layer-toggle` → Task 1 Step 2 (`game-on`/`game-off`). ✓
- D2 identity layer, literal-not-`_` → Task 1 Step 4 (`gaming`) + the rule in Global Constraints. ✓
- D3 `Fn+G` symmetric via `funcs-game` twin → Task 1 Steps 2–4. ✓
- D4 TCP on stock binary, no `(cmd…)` → Task 2 + Global Constraints. ✓
- D5 toast + SketchyBar → Tasks 3 + 4. ✓
- D6 clickable toggle (bidirectional `ChangeLayer`) → Task 4 Steps 1, 6. ✓
- D7 `base` first / restart bailout → Global Constraints; preserved (new layers appended after `base`). ✓
- Feedback data-flow (listener filter, de-dupe, reconnect, seed-on-connect) → Task 3 Step 1. ✓
- File/component table (kbd, plist, listener.sh, listener.plist, kanata_mode.sh, sketchybarrc, setup_mac.sh) → all have tasks. ✓
- Escape hatches: `Fn+G`/click (Tasks 1, 4); restart→base (Global Constraint + Task 1 reload). Optional both-Shifts panic chord is spec-"optional / verify syntax" — **intentionally deferred**, not implemented here (noted below).

**2. Placeholder scan:** No `TBD`/`TODO`/"add error handling"/"similar to". `__USER__`/`__KANATA__` are real placeholders consumed by the existing `sed` substitution pattern, not plan gaps. ✓

**3. Type/name consistency:** Layer strings `gaming`/`base` identical across kbd (`layer-switch`), listener (`jq` filter + `case`), and click handler (`ChangeLayer`). State file path `~/.cache/kanata/layer` identical in listener + plugin. Item name `kanata_mode` identical in listener `--set`, plugin, and `sketchybarrc`. Port `10000` / env `KANATA_PORT` identical across plist, listener, plugin. ✓

**Deferred (spec "Out of scope" / "optional"):** both-Shifts `defchordsv2` panic chord (syntax needs per-version verification) and app-focus auto-switch. Neither is required for a working toggle; both are additive later.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-24-kanata-gaming-layer.md`.

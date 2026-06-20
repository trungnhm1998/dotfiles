# Kanata Keyboard Remapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **NOTE — this is systems/hardware work, not unit-testable code.** The automated gate is `kanata --check` (config parse) + `bash -n`/`shellcheck` (scripts). Behavior is verified **manually at the keyboard**. Tasks are tagged **[AGENT]** (file edits an agent can do) or **[MANUAL]** (requires the user at the machine: GUI approvals, physical key testing). An agent executing this plan must **stop at each [MANUAL] step and hand off to the user**.

**Goal:** Replace Karabiner-Elements with Kanata on the MacBook built-in keyboard, replicating the ZSA Voyager base layer (home-row mods, Caps→Esc/Ctrl, Hyper/Meh) plus a Space-held nav layer, all as config in this dotfiles repo.

**Architecture:** A single `kanata.kbd` (defcfg + defsrc + base/nav deflayers + aliases), symlinked into `~/.config/kanata/`, run as a root LaunchDaemon against the pqrs VirtualHID driver, pinned to the built-in keyboard via `macos-dev-names-include`. Built up incrementally and tested in the foreground before being made persistent; Karabiner removed only once Kanata is proven.

**Tech Stack:** Kanata (Rust), Karabiner-DriverKit-VirtualHIDDevice (pqrs), Homebrew, macOS `launchd`, bash.

**Spec:** `docs/superpowers/specs/2026-06-20-kanata-keyboard-remapping-design.md`

---

## File Structure

| File | Responsibility |
|------|----------------|
| `.config/kanata/kanata.kbd` | The keymap: defcfg, defsrc, `base`/`nav` deflayers, aliases. Single source of truth. |
| `.config/kanata/dev.kanata.kanata.plist` | LaunchDaemon template (username/path substituted at install). |
| `scripts/kanata-reload.sh` | Reload helper (`launchctl kickstart`), since Kanata has no auto-reload-on-save. |
| `setup_mac.sh` | Add: `brew install kanata`, symlink, daemon install, permission prompt; remove Karabiner. |
| `README.md`, `CLAUDE.md`, `AGENTS.md` | Document the Kanata setup + config-file tables. |

> Kanata key-name reminders used below: right arrow is `rght`; left Cmd is `lmet`, right Cmd `rmet`; right Option is `ralt`. Hyper = `(multi lctl lsft lalt lmet)`, Meh = `(multi lctl lsft lalt)`.

---

## Task 1: Config scaffold — Caps→Esc/Ctrl only **[AGENT]**

**Files:**
- Create: `.config/kanata/kanata.kbd`

- [ ] **Step 1: Install the kanata binary**

Run: `brew install kanata`
Expected: installs; `kanata --version` prints a version (note it — you need it in Task 2 to pin the driver).

- [ ] **Step 2: Write the minimal config**

Create `.config/kanata/kanata.kbd`:

```lisp
;; kanata.kbd — MacBook built-in keyboard remap (ZSA Voyager port)
;; Pinned to the built-in keyboard only; the external Voyager is untouched.

(defcfg
  process-unmapped-keys yes
  macos-dev-names-include (
    "Apple Internal Keyboard / Trackpad"
  )
)

(defsrc
  caps
)

(defalias
  ;; Caps: tap Esc / hold Left-Ctrl. Plain tap-hold = decides only on
  ;; timeout-or-release, so it CANNOT misfire under Alfred (the bug we fix).
  cap (tap-hold 180 180 esc lctl)
)

(deflayer base
  @cap
)
```

- [ ] **Step 3: Validate the config parses**

Run: `kanata --cfg .config/kanata/kanata.kbd --check`
Expected: prints success / "config is valid" and exits 0. If it errors on `macos-dev-names-include`, run `kanata --list` later (Task 2) to get the exact built-in keyboard name and adjust the string.

- [ ] **Step 4: Symlink into ~/.config**

Run: `ln -sf "$HOME/dotfiles/.config/kanata" "$HOME/.config/kanata"`
Verify: `readlink ~/.config/kanata` points at the repo dir.

- [ ] **Step 5: Commit**

```bash
git add .config/kanata/kanata.kbd
git commit -m "feat(kanata): minimal config — Caps to Esc/Ctrl"
```

---

## Task 2: Driver + permissions + first foreground test **[MANUAL — at the machine]**

No file changes — this proves the engine end-to-end with the simplest config. Keep your **Voyager plugged in**; if the built-in keyboard ever misbehaves, type on the Voyager or hit the panic exit `Ctrl+Space+Esc`.

- [ ] **Step 1: Find the pinned driver version**

Open the installed kanata's macOS setup doc for YOUR version: `https://github.com/jtroo/kanata/blob/v<VERSION-from-Task1>/docs/setup-macos.md`. Note the exact **Karabiner-DriverKit-VirtualHIDDevice** version it pins.

- [ ] **Step 2: Install that exact driver**

Download the matching `.pkg` from `https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases`, install it. Do **not** grab "latest" — match the doc (the pqrs IPC protocol drifts between versions).

- [ ] **Step 3: Approve the driver extension**

System Settings → General → Login Items & Extensions → Driver Extensions → enable `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice`; approve "pqrs.org" under Privacy & Security. Activate the driver daemon per the setup doc (the VirtualHIDDevice-Manager `activate` step). Reboot if prompted.

- [ ] **Step 4: Grant kanata permissions**

Run: `kanata --macos-request-permissions`
Then in System Settings → Privacy & Security, enable **Input Monitoring** and **Accessibility** for kanata.

- [ ] **Step 5: Quit Karabiner-Elements (temporarily)**

Quit the Karabiner-Elements menu-bar app + Karabiner-Elements settings (do NOT uninstall yet — that's Task 7). Kanata and Karabiner must not both grab the built-in keyboard.

- [ ] **Step 6: Confirm the built-in keyboard's device name**

Run: `kanata --list`
Confirm the built-in keyboard's name matches the `macos-dev-names-include` string in `kanata.kbd`. If different, edit the string and re-run `--check`.

- [ ] **Step 7: Run in foreground and test**

Run: `sudo kanata --cfg ~/.config/kanata/kanata.kbd`
On the **built-in** keyboard verify:
- Tap **Caps** → `Esc` (test in a text field).
- Hold **Caps** + `c` → Ctrl+C.
- **The bug check:** open Alfred, type, tap Caps to dismiss / send Esc — confirm it's reliably `Esc`, never a stray Ctrl.
- On the **Voyager**: Caps/keys behave normally (untouched).
Stop with `Ctrl+C` in the terminal when done.

- [ ] **Step 8: Record the result** in the task notes (pass/fail + the verified device name). No commit (no file change).

---

## Task 3: Home-row mods (opposite-hand) **[AGENT writes, MANUAL tests]**

**Files:**
- Modify: `.config/kanata/kanata.kbd`

- [ ] **Step 1: Add defvars, aliases, and home-row keys**

Replace the file body with (keeps Task-1 Caps, adds A/S/D/F/J/K/L/;):

```lisp
;; kanata.kbd — MacBook built-in keyboard remap (ZSA Voyager port)

(defcfg
  process-unmapped-keys yes
  macos-dev-names-include (
    "Apple Internal Keyboard / Trackpad"
  )
)

(defvar
  tt 180          ;; home-row tap timeout
  ht 180          ;; home-row hold timeout
  ;; same-hand key lists: pressing a SAME-hand key forces the tap (letter),
  ;; so same-hand rolls never become modifiers. Cross-hand keeps the hold.
  left-hand  (q w e r t a s d f g z x c v b)
  right-hand (y u i o p h j k l ; n m , . /)
)

(defalias
  cap (tap-hold 180 180 esc lctl)

  ;; C-S-A-G order (pinky->index): Ctrl Shift Alt Cmd, mirrored.
  a    (tap-hold-release-keys $tt $ht a lctl $left-hand)
  s    (tap-hold-release-keys $tt $ht s lsft $left-hand)
  d    (tap-hold-release-keys $tt $ht d lalt $left-hand)
  f    (tap-hold-release-keys $tt $ht f lmet $left-hand)
  j    (tap-hold-release-keys $tt $ht j rmet $right-hand)
  k    (tap-hold-release-keys $tt $ht k ralt $right-hand)
  l    (tap-hold-release-keys $tt $ht l rsft $right-hand)
  scln (tap-hold-release-keys $tt $ht ; rctl $right-hand)
)

(defsrc
  caps
  a    s    d    f    j    k    l    ;
)

(deflayer base
  @cap
  @a   @s   @d   @f   @j   @k   @l   @scln
)
```

- [ ] **Step 2: Validate**

Run: `kanata --cfg .config/kanata/kanata.kbd --check`
Expected: success. If `;` in `defsrc` errors (it can collide with the `;;` comment lexer), replace the bare `;` token with the spelled key name your kanata version uses and re-check.

- [ ] **Step 3: [MANUAL] Foreground test**

Run: `sudo kanata --cfg ~/.config/kanata/kanata.kbd`
Verify on the built-in keyboard:
- Normal typing: `asdf jkl;` types the letters (no stray modifiers) — type a few fast sentences.
- Hold `f` + `j` → Cmd behavior (e.g. in Finder, hold f then tap j... use `f`+`tab` = Cmd+Tab app switcher as a clear test).
- Same-hand: hold `a`, tap `s` → should produce `as` (letters), NOT Ctrl+S. This proves the opposite-hand list.
- If same-hand combos fire mods (inverted behavior), the `$left-hand`/`$right-hand` lists are reversed — fix and retest.
Stop with `Ctrl+C`.

- [ ] **Step 4: Commit**

```bash
git add .config/kanata/kanata.kbd
git commit -m "feat(kanata): C-S-A-G home-row mods with opposite-hand resolution"
```

---

## Task 4: Bottom-row Hyper/Meh + Right-Option Hyper **[AGENT writes, MANUAL tests]**

**Files:**
- Modify: `.config/kanata/kanata.kbd`

- [ ] **Step 1: Add Hyper/Meh aliases and keys**

In the `defalias` block, add:

```lisp
  hyp  (multi lctl lsft lalt lmet)   ;; Hyper ⌃⇧⌥⌘
  meh  (multi lctl lsft lalt)        ;; Meh   ⌃⇧⌥
  z    (tap-hold 250 250 z @hyp)
  x    (tap-hold 250 250 x @meh)
  dot  (tap-hold 250 250 . @meh)
  slsh (tap-hold 250 250 / @hyp)
```

Extend `defsrc` to:

```lisp
(defsrc
  caps
  a    s    d    f    j    k    l    ;
  z    x    .    /
  ralt
)
```

Extend `deflayer base` to match (same order):

```lisp
(deflayer base
  @cap
  @a   @s   @d   @f   @j   @k   @l   @scln
  @z   @x   @dot @slsh
  @hyp
)
```

(Right Option `ralt` → `@hyp` makes it a held Hyper key.)

- [ ] **Step 2: Validate**

Run: `kanata --cfg .config/kanata/kanata.kbd --check`
Expected: success.

- [ ] **Step 3: [MANUAL] Foreground test**

Run: `sudo kanata --cfg ~/.config/kanata/kanata.kbd`
Verify:
- Tap `z` `x` `.` `/` → the literal characters (type them in a doc).
- Hold `z` + a key, or **Right Option** + a key → fires a Hyper combo (test with a Hyper-bound shortcut, e.g. an Alfred/Raycast Hyper hotkey, or check in Karabiner EventViewer-equivalent / a key tester).
- Hold `x` / `.` → Meh combo.
Stop with `Ctrl+C`.

- [ ] **Step 4: Commit**

```bash
git add .config/kanata/kanata.kbd
git commit -m "feat(kanata): bottom-row Hyper/Meh + Right-Option Hyper"
```

---

## Task 5: Phase 2 — Space-held nav layer **[AGENT writes, MANUAL tests]**

**Files:**
- Modify: `.config/kanata/kanata.kbd`

- [ ] **Step 1: Add the Space alias, nav keys, and nav layer**

In `defalias`, add:

```lisp
  ;; Space: tap Space / hold = nav layer. Roll-safe variant so fast typing
  ;; never triggers the layer.
  spc (tap-hold-release 180 200 spc (layer-while-held nav))
```

Extend `defsrc` (append the nav-input keys):

```lisp
(defsrc
  caps
  a    s    d    f    j    k    l    ;
  z    x    .    /
  ralt
  spc  h    y    u    i    o
)
```

Extend `deflayer base` to match (append; `h y u i o` are plain on base):

```lisp
(deflayer base
  @cap
  @a   @s   @d   @f   @j   @k   @l   @scln
  @z   @x   @dot @slsh
  @hyp
  @spc h    y    u    i    o
)
```

Add the `nav` layer (left hand = live mods for composition; right hand = arrows + Home/End/PgUp/PgDn):

```lisp
(deflayer nav
  _
  lctl lsft lalt lmet down up   rght _
  _    _    _    _
  _
  _    left home pgdn pgup end
)
```

Layout reference: `H`←  `J`↓  `K`↑  `L`→ ; `Y`=Home `U`=PgDn `I`=PgUp `O`=End.

- [ ] **Step 2: Validate**

Run: `kanata --cfg .config/kanata/kanata.kbd --check`
Expected: success. (Confirm `defsrc` and BOTH deflayers have the same key count, 20.)

- [ ] **Step 3: [MANUAL] Foreground test**

Run: `sudo kanata --cfg ~/.config/kanata/kanata.kbd`
Verify (hold Space the whole time unless noted):
- `Space`-hold + `h/j/k/l` → ← ↓ ↑ → (move the caret in a doc).
- `Space`-hold + `y/o` → line start/end; `Space`-hold + `u/i` → page down/up.
- Composition: `Space`+`s`(Shift)+`l` → selects right; `Space`+`f`(Cmd)+`l` → jump to line end; `Space`+`d`(Opt)+`l` → word right.
- Tap `Space` alone (no other key) → a normal space; fast typing with spaces is unaffected (no accidental nav).
Stop with `Ctrl+C`.

- [ ] **Step 4: Commit**

```bash
git add .config/kanata/kanata.kbd
git commit -m "feat(kanata): Space-held nav layer (hjkl arrows + Home/End/PgUp/PgDn)"
```

---

## Task 6: Persistent LaunchDaemon **[AGENT writes, MANUAL installs]**

**Files:**
- Create: `.config/kanata/dev.kanata.kanata.plist`

- [ ] **Step 1: Write the plist template**

Create `.config/kanata/dev.kanata.kanata.plist` (the `__USER__` and `__KANATA__` tokens are substituted at install):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.kanata.kanata</string>
  <key>ProgramArguments</key>
  <array>
    <string>__KANATA__</string>
    <string>--no-wait</string>
    <string>--cfg</string>
    <string>/Users/__USER__/.config/kanata/kanata.kbd</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/kanata.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/kanata.err.log</string>
</dict>
</plist>
```

- [ ] **Step 2: [MANUAL] Install and load the daemon**

```bash
# stop any foreground kanata first (Ctrl+C in its terminal)
sudo cp ~/.config/kanata/dev.kanata.kanata.plist /Library/LaunchDaemons/dev.kanata.kanata.plist
sudo sed -i '' "s|__KANATA__|$(which kanata)|; s|__USER__|$USER|" /Library/LaunchDaemons/dev.kanata.kanata.plist
sudo chown root:wheel /Library/LaunchDaemons/dev.kanata.kanata.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist
```

- [ ] **Step 3: [MANUAL] Verify persistence**

Confirm the remaps work without a foreground process: `sudo launchctl print system/dev.kanata.kanata | grep state` (expect running). Test Caps→Esc + a home-row chord. Check `/tmp/kanata.err.log` is clean. Reboot and confirm it still works at login.

- [ ] **Step 4: Commit**

```bash
git add .config/kanata/dev.kanata.kanata.plist
git commit -m "feat(kanata): persistent LaunchDaemon template"
```

---

## Task 7: Remove Karabiner-Elements **[MANUAL]**

Only after the daemon is proven (Task 6). Keep the **pqrs driver** — Kanata needs it.

- [ ] **Step 1: Quit & uninstall Karabiner-Elements**

Use Karabiner-Elements' own uninstaller (Preferences → Misc → Uninstall) or delete the app per pqrs docs. Do **not** remove `Karabiner-DriverKit-VirtualHIDDevice`.

- [ ] **Step 2: Verify**

Reboot. Confirm: Kanata daemon still running, all remaps work on the built-in keyboard, Voyager untouched, no Karabiner menu-bar icon, `/tmp/kanata.err.log` clean.

- [ ] **Step 3: Record** completion in notes (no commit — system change only; any repo Karabiner references are handled in Task 8).

---

## Task 8: Wire into `setup_mac.sh` **[AGENT]**

**Files:**
- Modify: `setup_mac.sh`

- [ ] **Step 1: Read the file first**

Run: `cat -n setup_mac.sh` (locate the `brew install \` list, the `ln -sf` symlink block, the `brew services` block, and any existing `karabiner` reference).

- [ ] **Step 2: Add kanata to the brew install list**

In the `brew install \` formula list, add `kanata` (alphabetical-ish, matching existing style). If a `karabiner-elements` cask exists in the `brew install --cask` list, remove that line (we no longer use it).

- [ ] **Step 3: Add the symlink**

In the `ln -sf` block, add:

```bash
ln -sf $HOME/dotfiles/.config/kanata $HOME/.config/kanata
```

- [ ] **Step 4: Add the daemon-install block**

After the symlink block (or near the `brew services` section), add:

```bash
# --- kanata keyboard remapper (built-in keyboard only) ---
# Requires the pqrs Karabiner-DriverKit-VirtualHIDDevice driver (install manually,
# pinned to the version in kanata's setup-macos.md). See README "Kanata" section.
if [ ! -f /Library/LaunchDaemons/dev.kanata.kanata.plist ]; then
  sudo cp "$HOME/dotfiles/.config/kanata/dev.kanata.kanata.plist" /Library/LaunchDaemons/dev.kanata.kanata.plist
  sudo sed -i '' "s|__KANATA__|$(which kanata)|; s|__USER__|$USER|" /Library/LaunchDaemons/dev.kanata.kanata.plist
  sudo chown root:wheel /Library/LaunchDaemons/dev.kanata.kanata.plist
  sudo launchctl bootstrap system /Library/LaunchDaemons/dev.kanata.kanata.plist
  echo "kanata daemon installed. Grant Input Monitoring + Accessibility to"
  echo "  $(which kanata) (and your terminal app) in System Settings > Privacy & Security."
fi
```

- [ ] **Step 5: Syntax-check**

Run: `bash -n setup_mac.sh && shellcheck setup_mac.sh`
Expected: `bash -n` clean. Address any new `shellcheck` findings on the lines you added (pre-existing warnings elsewhere may be left as-is to match the file's current state).

- [ ] **Step 6: Commit**

```bash
git add setup_mac.sh
git commit -m "feat(setup): install kanata + daemon, drop karabiner-elements"
```

---

## Task 9: Reload helper script **[AGENT]**

**Files:**
- Create: `scripts/kanata-reload.sh`

- [ ] **Step 1: Write the script**

Create `scripts/kanata-reload.sh`:

```bash
#!/bin/bash
# Reload the kanata LaunchDaemon after editing kanata.kbd.
# (Kanata has no auto-reload-on-save on macOS.)
set -euo pipefail

if ! kanata --cfg "$HOME/.config/kanata/kanata.kbd" --check; then
  echo "Config invalid — not reloading." >&2
  exit 1
fi

sudo launchctl kickstart -k system/dev.kanata.kanata
echo "kanata reloaded."
```

- [ ] **Step 2: Make executable + syntax-check**

Run: `chmod +x scripts/kanata-reload.sh && bash -n scripts/kanata-reload.sh && shellcheck scripts/kanata-reload.sh`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add scripts/kanata-reload.sh
git commit -m "feat(scripts): kanata-reload helper with pre-check"
```

---

## Task 10: Documentation **[AGENT]**

**Files:**
- Modify: `README.md`, `CLAUDE.md`, `AGENTS.md`

- [ ] **Step 1: Read each file first**

Run: `cat -n README.md` and re-read `CLAUDE.md` / `AGENTS.md` (they are edited out-of-band — read immediately before editing). Find the config-file tables and a sensible spot for a new section.

- [ ] **Step 2: Add a Kanata section to `README.md`**

Insert:

```markdown
## Keyboard Remapping (Kanata)

The MacBook built-in keyboard is remapped with [Kanata](https://github.com/jtroo/kanata)
to mirror the ZSA Voyager layout. Config: `.config/kanata/kanata.kbd` (single source).

- **Caps Lock** → tap `Esc` / hold `Ctrl`
- **Home-row mods** (C-S-A-G): `A/S/D/F` = Ctrl/Shift/Alt/Cmd, `J/K/L/;` mirrored,
  opposite-hand resolution (same-hand rolls stay letters). For same-hand combos
  (e.g. Cmd+Q), use the **opposite** hand's mod.
- **Z/X/./?** → Hyper/Meh; **Right Option** → Hyper.
- **Hold Space** → nav layer: `hjkl` = arrows, `Y/U/I/O` = Home/PgDn/PgUp/End;
  combine with the live left-hand mods for select/word/line motions.
- **Panic exit:** `Ctrl+Space+Esc`. The external Voyager is never remapped.

**Setup (one-time):** install the pqrs Karabiner-DriverKit-VirtualHIDDevice driver
(version pinned in kanata's `setup-macos.md`, currently v6.2.0), approve the driver
extension, grant Input Monitoring + Accessibility to `/opt/homebrew/bin/kanata`. `setup_mac.sh`
installs kanata + the LaunchDaemon. Reload after edits: `scripts/kanata-reload.sh`.
```

- [ ] **Step 3: Add rows to the config tables in `CLAUDE.md` and `AGENTS.md`**

In each "Key Configuration Files" / "Key File Locations" table, add:

```markdown
| Kanata (keyboard remap) | `.config/kanata/kanata.kbd` (+ `dev.kanata.kanata.plist`) |
```

In `CLAUDE.md`, also add a one-line note under the macOS window-management/architecture area:

```markdown
- **Keyboard:** Kanata remaps the built-in keyboard only (ZSA Voyager port); root LaunchDaemon + pqrs driver. See README "Keyboard Remapping (Kanata)".
```

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md AGENTS.md
git commit -m "docs(kanata): document keyboard remapping setup"
```

---

## Self-Review (completed during authoring)

- **Spec coverage:** Caps→Esc/Ctrl (T1–2), C-S-A-G opposite-hand HRM (T3), Hyper/Meh + Right-Opt (T4), Space nav layer w/ chosen extras (T5), device pinning + daemon (T1/T6), Karabiner removal keeping driver (T7), setup_mac.sh + reload + docs (T8–10), panic exit & escape hatch (called out in T2). Windows is deferred per spec §9 — intentionally no task.
- **Type/name consistency:** alias names (`@cap @a…@scln @z @x @dot @slsh @hyp @spc`) and layer names (`base`, `nav`) are consistent across tasks; `defsrc`/`deflayer` counts reconciled to 20 in T5.
- **Known-verify points (flagged inline):** the bare `;` token in `defsrc` (lexer), `macos-dev-names-include` exact device name (`kanata --list`), `tap-hold-release-keys` list direction (manual same-hand test in T3), and the pinned driver version. Each has a concrete fallback step.

---

## Risks / reminders for the executor

- **Never leave the machine without a working keyboard.** Keep the Voyager plugged in during Tasks 2–7; the panic exit is `Ctrl+Space+Esc`.
- **Do not run Karabiner remapping and Kanata on the same keyboard simultaneously** — quit Karabiner during dev (T2), uninstall only at T7.
- **`sudo` is required** to run kanata and manage the daemon on macOS.
- An agent must **pause at every [MANUAL] step** and hand control to the user.

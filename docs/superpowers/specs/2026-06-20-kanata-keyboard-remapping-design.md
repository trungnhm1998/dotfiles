# Kanata Keyboard Remapping — Design Spec

- **Date:** 2026-06-20
- **Status:** Approved (ready for implementation plan)
- **Scope:** Replace Karabiner-Elements with Kanata on the MacBook Pro (M4) built-in keyboard, replicating the ZSA Voyager layout as config-as-code in this dotfiles repo. Windows is **deferred** (documented, not implemented).

---

## 1. Problem & goals

Max's daily driver is a ZSA Voyager (QMK firmware: home-row mods, layers, tap-holds). On the go he uses the MacBook's **built-in** keyboard, today remapped with Karabiner-Elements. The Karabiner setup is **unreliable**: tapping the Esc/Ctrl key (currently Caps Lock) misfires — notably while using Alfred — emitting `Ctrl` (or swallowing `Esc`) instead of `Esc`.

**Root cause (verified):** Karabiner's `to_if_alone` cancels the tap **the instant any other key is pressed while the key is down**, and posts the tap only on release. That is structurally equivalent to QMK's "hold-on-other-key-press" — fast typing or rolls turn the tap into the hold. It is not tunable away. ([Karabiner `to_if_alone` docs](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to-if-alone/))

**Goals:**
1. Fix the tap-hold misfire (Caps → Esc) reliably, including under Alfred.
2. Replicate the Voyager **base layer** mod-taps on the built-in keyboard.
3. Add a single **navigation layer** (vim `hjkl` arrows on the home row).
4. Keep everything as **source-controlled config** in this dotfiles repo.
5. Touch **only** the built-in keyboard; leave the external Voyager untouched.

**Non-goals:** Porting the Voyager's Symbols/Numbers/F-key/RGB/mouse layers (the MacBook already has those physical keys — see §6). A persistent Windows setup (deferred — §9).

---

## 2. Decision: Kanata (not Karabiner)

Kanata wins on all three stated priorities:

| Priority | Why Kanata |
|----------|-----------|
| Reliable tap-hold | Plain `tap-hold` decides **only on timeout-or-release** — it does *not* hold-on-other-key-press, so the Alfred/roll misfire cannot occur. |
| QMK replication | Native `tap-hold` variants, `deflayer`, `layer-while-held`, opposite-hand home-row-mod primitives — Voyager logic translates ~1:1. |
| Config-as-code | One plain-text `.kbd` (Lisp S-expressions); commits cleanly; same file works cross-OS later. |

([Kanata config guide](https://jtroo.github.io/config.html))

**Accepted costs** (macOS): runs as a **root** LaunchDaemon; depends on the **pqrs Karabiner-DriverKit-VirtualHIDDevice** driver pinned to an *exact* version; no auto-reload-on-save; macOS is the maintainer's least-supported platform (community-maintained, some open crash bugs). These are acceptable for a dotfiles-as-code workflow.

---

## 3. Scope & phasing

- **Phase 1 — ZSA base layer + infrastructure.** The mod-taps + the daemon/driver/dotfiles/docs plumbing. First implementation target.
- **Phase 2 — Space-held navigation layer.** `hjkl` arrows + nav cluster.
- **Deferred — Windows.** Research captured in §9; not built now.

---

## 4. Architecture (macOS)

```
physical keypress
  → Kanata (root LaunchDaemon, pinned to built-in keyboard via macos-dev-names-include)
  → remap per kanata.kbd
  → pqrs VirtualHID driver (IPC over root-only socket)
  → macOS input stack
```

**Components**
- **`kanata`** — installed via Homebrew (`brew install kanata`), run as a root LaunchDaemon (`dev.kanata.kanata`).
- **Karabiner-DriverKit-VirtualHIDDevice** — standalone pqrs driver (full Karabiner-Elements **not** required). Pin to the **exact** version named in `setup-macos.md` for the installed Kanata release; the pqrs IPC protocol drifts between minor versions, so "latest" can break. ([setup-macos.md](https://github.com/jtroo/kanata/blob/main/docs/setup-macos.md))
- **Device pinning** — `macos-dev-names-include` set to the built-in keyboard's device name (verify via `kanata --list`; expected `"Apple Internal Keyboard / Trackpad"`). Any external keyboard (the Voyager) is therefore untouched **and** doubles as a hardware escape hatch.

**Permissions** (one-time, cannot be fully scripted): approve the pqrs driver extension (System Settings → General → Login Items & Extensions → Driver Extensions), grant **Input Monitoring** + **Accessibility** (`kanata --macos-request-permissions` triggers the prompts).

---

## 5. Phase 1 — base layer

Remapped keys on the built-in keyboard (everything else passes through):

| Key | Tap | Hold |
|-----|-----|------|
| **Caps Lock** | `Esc` | **L-Ctrl** |
| **A / S / D / F** | a s d f | **Ctrl / Shift / Alt / Cmd** |
| **J / K / L / ;** | j k l ; | **Cmd / Alt / Shift / Ctrl** |
| **'** | ' | *(plain — see note)* |
| **Z / /** | z / | **Hyper** (⌃⇧⌥⌘) |
| **X / .** | x . | **Meh** (⌃⇧⌥) |
| **Right Option** | — | **Hyper** (⌃⇧⌥⌘) |
| **Tab** | tab | *(plain)* |
| **Space** | space | *(plain in P1 → nav layer in P2)* |

**Home-row mod order is C-S-A-G** (pinky→index: Ctrl, Shift, Alt, Cmd), mirrored on the right — taken verbatim from the Voyager firmware, **not** the GACS Max originally assumed.

**Notes / decisions:**
- **`'` stays a plain `'`.** The firmware makes `'` also hold Right-Ctrl (duplicate of `;`), but on a laptop `'` is high-frequency (contractions/quotes) and a hold-mod there would misfire.
- **Esc/Ctrl lives on Caps Lock only** (faithful to the Voyager's left-pinky key). Tab stays a normal Tab.
- **No numpad**, **no Cmd+hjkl arrows** (the old Karabiner idioms are dropped; arrows return via the Phase 2 nav layer).
- **Right Option → Hyper** and the **Z/X/./? Hyper/Meh** mod-taps are carried over.

### Home-row mod tuning — opposite-hand

The Voyager resolves mod-taps on a pure timer (180 ms; 250 ms on the Z/X/./? Hyper/Meh keys), with **no** permissive-hold or opposite-hand logic. That is fine on a column-staggered ergo board but misfires on a row-staggered laptop typed fast. **Decision: use opposite-hand resolution** — a mod fires only when the *next* key is on the **other hand**, so same-hand rolls (`as`, `sd`, `jkl`) stay letters while real cross-hand chords activate immediately.

Implementation: prefer Kanata's **`chordal-hold`** (the dedicated opposite-hand rule) if present in the installed version (≥ v1.11); otherwise the `tap-hold-release-tap-keys-release` pattern from the official `home-row-mod-advanced.kbd` sample. Starting timings: **180 ms** home row, **250 ms** Z/X/./?. Tune after living on it.

Illustrative (exact syntax pinned at implementation against the installed version):

```lisp
(defalias
  cap (tap-hold 180 180 esc lctl)              ;; plain tap-hold = the Alfred fix
  hyp (multi lctl lsft lalt lmet)              ;; Hyper
  meh (multi lctl lsft lalt)                   ;; Meh
  a   (tap-hold-release-tap-keys 180 180 a lctl $right-hand-keys)
  z   (tap-hold 250 250 z @hyp))
```

---

## 6. Phase 2 — Space-held navigation layer

**Why only one layer:** the Voyager's Symbols/Numbers/F-key layers exist to *recreate keys the 52-key board lacks*. The MacBook keyboard already has a number row, all symbols, and a function row — porting those layers would rebuild keys that are already present. The one thing a laptop genuinely lacks is **home-row navigation**. So "many Voyager layers" collapses to **one nav layer**.

`Space` = tap `Space` / **hold = nav layer**. While held:

```
LEFT HAND (mods stay LIVE)            RIGHT HAND (vim nav)
  Q  W  E  R  T                         Y      U      I      O      P
 [A  S  D  F] G                         H      J      K      L      ;
  Ctrl Shift Alt Cmd                    ←      ↓      ↑      →
  Z  X  C  V  B                         N  M  ,  .  /

  Y = Home   U = PgDn   I = PgUp   O = End
  H = ←      J = ↓      K = ↑      L = →
```

- **Core:** `H J K L → ← ↓ ↑ →`.
- **Extras (chosen):** `Home / End` on `Y / O`; `Page Down / Page Up` on `U / I` — aligned above the arrows (Home over ←, End over →, page keys over their vertical column).
- **Left-hand mods stay live** on the layer. This yields a full motion system by **composition**, with no extra keys:

  | Motion | Press (Space held) |
  |--------|--------------------|
  | move | `H J K L` |
  | select | `Shift`(S) + arrow |
  | word L/R | `Opt`(D) + `H`/`L` |
  | line start/end | `Cmd`(F) + `H`/`L` |
  | select word/line | `Shift`+`Opt`/`Cmd` + arrow |

Space is high-frequency, so the layer-hold uses a roll-safe variant (e.g. `tap-hold-release` / `tap-hold-release-keys`), tuned so fast typing never triggers the layer.

```lisp
(defalias spc (tap-hold-release 200 200 spc (layer-while-held nav)))
```

---

## 7. Config structure & dotfiles integration

### Config file

A single `kanata.kbd` for the macOS-only build now:

```
.config/kanata/
  kanata.kbd                 ; defcfg (macos-dev-names-include) + defsrc + deflayer base/nav + defalias
  dev.kanata.kanata.plist    ; macOS root LaunchDaemon template
```

> **Cross-platform note:** when Windows is added (§9), refactor to `base.kbd` (defsrc/deflayer/defalias, no `defcfg`) + per-OS wrappers (`kanata-macos.kbd`, `kanata-windows.kbd`) that each hold one `defcfg` then `(include base.kbd)`. OS-specific `defcfg` options are silently ignored on the wrong OS (verified in Kanata's parser source), so this is safe. Single `defcfg` per resolved config; `(include)` is top-level only and non-nesting.

### Symlinks & deploy (`setup_mac.sh`)

- `brew install kanata`.
- Symlink `.config/kanata` → `~/.config/kanata` (matches the repo's `ln -sf` pattern).
- Install the LaunchDaemon: copy `dev.kanata.kanata.plist` → `/Library/LaunchDaemons/` (`sudo`, `root:wheel`), `launchctl bootstrap system …`. The plist runs `kanata --cfg /Users/<user>/.config/kanata/kanata.kbd` with an **absolute** path (root's `~` ≠ the user's).
- Print one-time manual steps: install the pinned pqrs driver pkg, approve the system extension, run `kanata --macos-request-permissions`.

### Reload

No auto-reload-on-save. Provide both: an `lrld` keybind inside the config, and `scripts/kanata-reload.sh` (`sudo launchctl kickstart -k system/dev.kanata.kanata`).

### Karabiner disposition

**Uninstall Karabiner-Elements**, keep the standalone pqrs driver. Max's current KE rules only touch the built-in keyboard (the Voyager is already `ignore`d), so once Kanata owns the built-in, KE is fully redundant. Do **not** run KE remapping and Kanata on the same keyboard — they fight over the device.

### Documentation deliverables

- `README.md` — add a Kanata section (what/why, the keymap summary, setup steps).
- `CLAUDE.md` + `AGENTS.md` — add Kanata to the config-file tables and a short "keyboard remapping" architecture note. (Re-read these immediately before editing — they are edited out-of-band.)

---

## 8. Safety, testing, validation

**Escape hatches**
- External keyboard stays unmapped (device pinning) → instant physical fallback.
- Hard panic-exit **`Ctrl + Space + Esc`** (operates on pre-remap input; always works).
- A bad config can't brick input — Kanata keeps the last-good config on reload failure.

**Validation**
- `kanata --check kanata.kbd` — add to repo validation/CI.
- `bash -n setup_mac.sh` + `shellcheck` on script changes.
- Manual matrix: tap-Esc-into-Alfred (the bug); fast-roll test (`asdf jkl;` must emit letters, no mods); each cross-hand chord (e.g. `F`+`J` = Cmd); `Z/X/./?` Hyper/Meh; Right-Opt Hyper; Phase 2 — Space-hold arrows + Home/End/PgUp/PgDn + composed select/word/line motions.

---

## 9. Deferred — Windows (research captured)

Not implemented (Max chose to skip). The Voyager firmware already covers Windows; Max only occasionally types on a TKL / 60% hall-effect board there.

**Why deferred rather than built:** per-device targeting on Windows (remap the gaming board, exclude the Voyager) requires Kanata's **Interception driver** — the hook builds can't filter by device. Interception is a poor fit for this workflow:
- **Anti-cheat games block the driver** (EAC/Apex/BF refuse to launch with it loaded) — and the hall-effect board is the gaming board. ([discussion #184](https://github.com/jtroo/kanata/discussions/184))
- **A sleep/replug bug** stops input when sleeping the laptop or swapping keyboards — exactly the "mostly Voyager, sometimes gaming board" pattern. ([oblitum/Interception#25](https://github.com/oblitum/Interception/issues/25))

**Recommended path when revisited:** on-demand, **driver-free winIOv2 hook build** (`scoop install kanata`) with Kanata's native systray toggle — start it for typing on the gaming board, stop it for games or when on the Voyager (stopping Kanata *is* "game mode"). Refactor the config to the `base.kbd` + wrapper structure (§7) and add `kanata-windows.kbd` (`process-unmapped-keys`, AltGr-safe) → `(include base.kbd)`. Wire into `deploy_windows.ps1` (winget/scoop are already supported there).

---

## 10. Risks & open items (resolve in implementation)

- **`chordal-hold` availability** — verify it exists in the installed Kanata version; else use the advanced-sample opposite-hand pattern.
- **Driver version pin** — read the installed Kanata's `setup-macos.md` for the exact pqrs driver version; do not install "latest".
- **Built-in keyboard device name** — confirm via `kanata --list` before hardcoding `macos-dev-names-include`.
- **LaunchDaemon ↔ driver-daemon ordering** — ensure the pqrs VirtualHID daemon is active before/with Kanata.
- **Tuning** — 180/250 ms and the Space layer-hold timing are starting points; expect a tuning pass after daily use.

---

## Sources

- Kanata config guide — https://jtroo.github.io/config.html
- Kanata macOS setup — https://github.com/jtroo/kanata/blob/main/docs/setup-macos.md
- Kanata Windows platform issues — https://raw.githubusercontent.com/jtroo/kanata/main/docs/platform-known-issues.adoc
- Karabiner `to_if_alone` — https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to-if-alone/
- Interception anti-cheat — https://github.com/jtroo/kanata/discussions/184
- Interception sleep/replug bug — https://github.com/oblitum/Interception/issues/25
- ZSA Voyager layout — `~/Downloads/zsa_voyager_NZ3x6_Jamaj9_mint_source/zsa_voyager_mint_source/keymap.c` + `config.h`

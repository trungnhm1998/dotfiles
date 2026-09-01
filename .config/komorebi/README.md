# komorebi

Tiling window manager for Windows. Hotkeys are driven by AutoHotkey v2 (`komorebi.ahk`) on a **Hyper/Meh** scheme (Hyper = focus, Meh = move), with `Alt` left free for the terminal.

- **Keybindings manual → [`KEYBINDS.md`](./KEYBINDS.md)**
- WM config: `komorebi.json` · bar: **YASB** (`~/.config/yasb`) · app rules: `applications.json`
- Design docs: [`hyper-keybinds`](../../docs/superpowers/specs/2026-06-25-komorebi-hyper-keybinds-design.md) · [`modes + OSD`](../../docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md)

Config lives here and is symlinked via `KOMOREBI_CONFIG_HOME`, so edits are live. Start with `komorebic start`.

## WSLg focus steal (msrdc)

WSLg (`msrdc.exe /wslg`) steals OS foreground to invisible `TscShellContainerClass` shells. Komorebi borders follow `GetForegroundWindow()`, so ignore rules alone cannot keep borders focused — see research notes in this README section.

**WM-native mitigations:** `ignore_rules` + `applications.json` (Microsoft Terminal Services Client: `TscShellContainerClass`, `msrdc.exe`).

**Retired workaround (2026-08-17):** `focus-guard.ps1` restored OS foreground to komorebi's focused hwnd, but its synthetic Alt injection corrupted held Hyper chords and its `SetForegroundWindow` calls desynced komorebi focus from OS foreground (Hyper+H landed on wrong windows). Removed from `komorebi.ahk`; only the passive `ignore_rules` mitigation remains. Scripts kept on disk for reference.

Diagnostics: `focus-snapshot.ps1`, `focus-log.ps1`, `%TEMP%\wslg-guard.log`.

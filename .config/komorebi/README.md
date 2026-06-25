# komorebi

Tiling window manager for Windows. Hotkeys are driven by AutoHotkey v2 (`komorebi.ahk`) on a **Hyper/Meh** scheme (Hyper = focus, Meh = move), with `Alt` left free for the terminal.

- **Keybindings manual → [`KEYBINDS.md`](./KEYBINDS.md)**
- WM config: `komorebi.json` · bar: **YASB** (`~/.config/yasb`) · app rules: `applications.json`
- Design docs: [`hyper-keybinds`](../../docs/superpowers/specs/2026-06-25-komorebi-hyper-keybinds-design.md) · [`modes + OSD`](../../docs/superpowers/specs/2026-06-25-komorebi-modes-osd-design.md)

Config lives here and is symlinked via `KOMOREBI_CONFIG_HOME`, so edits are live. Start with `komorebic start`.

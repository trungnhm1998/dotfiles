# Catppuccin Frappe — Dotfiles Theme Reference

Canonical source for this repo's theming. Edit colors here first, then propagate.

## Palette (hex)
| Color | Hex | | Color | Hex |
|---|---|---|---|---|
| Rosewater | #f2d5cf | | Sky | #99d1db |
| Flamingo | #eebebe | | Sapphire | #85c1dc |
| Pink | #f4b8e4 | | Blue | #8caaee |
| Mauve | #ca9ee6 | | Lavender | #babbf1 |
| Red | #e78284 | | Text | #c6d0f5 |
| Maroon | #ea999c | | Subtext1 | #b5bfe2 |
| Peach | #ef9f76 | | Subtext0 | #a5adce |
| Yellow | #e5c890 | | Overlay2 | #949cbb |
| Green | #a6d189 | | Overlay1 | #838ba7 |
| Teal | #81c8be | | Overlay0 | #737994 |
| Surface2 | #626880 | | Surface1 | #51576d |
| Surface0 | #414559 | | Base | #303446 |
| Mantle | #292c3c | | Crust | #232634 |

## Base16 slot map (komorebi `palette: Base16`, `name: CatppuccinFrappe`)
Base00 base · Base01 mantle · Base02 surface0 · Base03 surface1 · Base04 surface2 · Base05 text · Base08 red · Base09 peach · Base0A yellow · Base0B green · Base0C teal · Base0D blue · Base0E mauve

## Accent map (roles)
- **Focus / active / selected (chrome):** Mauve `#ca9ee6`
- Inactive border: Surface1 `#51576d` · Dim/muted: Overlay1 `#838ba7` · Foreground: Text `#c6d0f5` · Background: Base `#303446`

## Semantics (fixed — never collapse to the accent)
- Leader mode (WezTerm): Pink `#f4b8e4` · Resize mode: Teal `#81c8be`
- Error/delete: Red `#e78284` · Success/add: Green `#a6d189` · Warning/modified: Yellow `#e5c890` · Alert badge: Peach `#ef9f76`

## Per-tool accent assignments
- **komorebi borders:** single/focused = Mauve (Base0E) · stack = Blue (Base0D) · monocle = Green (Base0B) · floating = Yellow (Base0A) · unfocused = Surface1 (Base03)
- **YASB:** active workspace pill = Mauve `#ca9ee6` (text Base `#303446`)
- **starship:** directory = mauve · git_branch = green · git_status = yellow · character = green/red (semantic)
- **PSReadLine:** Parameter/Keyword = mauve (accent); Command = blue; String = green; Error = red
- **eza/LS_COLORS:** vivid `catppuccin-frappe`
- **macOS borders (yabai):** active = Mauve `0xffca9ee6` · inactive = Surface1 `0xff51576d` · zoom = Red `0xffe78284`

## Scope note
Unified Mauve governs **chrome** (borders, pills, prompt, pickers). Editor **syntax** themes (Neovim, Zed) keep the full Frappe palette by design. Claude Code TUI is `dark-ansi` (inherits WezTerm's Frappe ANSI).

## Already-Frappe (do not re-theme)
WezTerm, tmux, Zellij, Neovim, Zed (Windows), yazi (active flavor), bat, fzf, lazygit, komorebi AHK OSD, Windows Terminal + Preview (via fragment).

## Claude statusline (ccstatusline) — known limitation
Active statusline is `ccstatusline` (node, via `bunx`), config at `~/.config/ccstatusline/settings.json`. In **minimalist (non-powerline) mode** it accepts only **named ANSI colors** (rendered as *generic* truecolor, NOT the terminal palette) — custom Frappe hex (`#ca9ee6` / `ca9ee6`) in a segment's `color` field is **silently ignored** (verified 2026-06-26). So exact Frappe Mauve is **not** achievable via the config file. Left as Max's working named-color config.

For exact Frappe, two options (Max's call):
1. **ccstatusline TUI** — `bunx -y ccstatusline@latest`, pick custom Frappe hex per segment (saved in ccstatusline's internal format), or enable powerline + a Catppuccin theme.
2. **In-repo bash statusline** — point `claude/settings.json` `statusLine.command` at `~/.claude/statusline-command.sh` (already pixel-perfect Frappe), trading ccstatusline's richer segments. First verify Windows execution + that it reads the *current* Claude Code statusline JSON (it expects `.model` as a string and `.context.*`, which the current schema may not provide).

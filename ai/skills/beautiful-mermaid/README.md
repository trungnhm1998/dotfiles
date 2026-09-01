# beautiful-mermaid (skill)

Terminal CLI to **review, render, and validate Mermaid diagrams** — rebuilt to
replace the old `beautiful-mermaid` skill. Lets Claude Code preview a diagram as
Unicode line-art *in the TUI* (the only image-like thing the terminal can show),
open a themed SVG, or validate against the real mermaid.js parser.

## Why this design
Claude Code's terminal can't render image pixels — it captures stdout as **text**.
Unicode box-drawing survives that; PNGs don't. So:

- **Rendering engine:** [`beautiful-mermaid`](https://github.com/lukilabs/beautiful-mermaid)
  (Luki Labs / Craft, MIT) — pure-TypeScript, **no headless Chromium**. Its ASCII
  engine is the Go `mermaid-ascii` engine ported and *extended* to 6 diagram types
  (flowchart, sequence, state, class, ER, XY), and it renders decision `{…}`
  diamonds correctly (the raw Go tool splits them). Also emits themed SVG.
- **Validation:** `mmdc` (mermaid-cli = real mermaid.js). beautiful-mermaid's own
  parser is lenient, so it's not a "will this render on GitHub/Obsidian" guarantee.
  `--check` is — at the cost of a ~1–2s Chromium spin-up, so it's opt-in.

This "mix" gives instant in-terminal review for the common case and an
authoritative gate exactly when correctness matters (pasting into the vault / PRs).

- **Rich browser view:** `--edit`/`--view` open the diagram in the official
  [mermaid.live](https://mermaid.live) editor using the *real* mermaid.js — pixel-faithful
  to GitHub/Obsidian, fully interactive (live edit, theme, export). The diagram is encoded
  into the URL **fragment** (`#pako:…`, zlib+base64 via Node's built-in `zlib`, no extra dep),
  which browsers never transmit to the server, so it stays client-side.

## Usage
```bash
S=~/.claude/skills/beautiful-mermaid/scripts/mermaid.mjs
node "$S" diagram.mmd               # ASCII to terminal (default)
node "$S" -                         # stdin
node "$S" --code "graph TD;A-->B"   # inline
node "$S" diagram.mmd --edit        # real mermaid.js — interactive editor (browser)
node "$S" diagram.mmd --view        # real mermaid.js — read-only viewer (browser)
node "$S" diagram.mmd --edit --url  # print the mermaid.live link only (no browser)
node "$S" diagram.mmd --check       # validate via mmdc, then render
node "$S" diagram.mmd --open        # themed SVG -> default app
node "$S" diagram.mmd --open --theme tokyo-night
node "$S" diagram.mmd --ascii       # plain ASCII charset
node "$S" diagram.mmd --svg out.svg # write SVG, no window
```
Themes: `zinc-light/dark`, `tokyo-night(-storm/-light)`, `catppuccin-mocha/latte`,
`nord(-light)`, `dracula`, `github-light/dark`, `solarized-light/dark`, `one-dark`.

## Install (per machine)
`node_modules/` is gitignored, so after pulling dotfiles:
```bash
npm install --prefix ~/.claude/skills/beautiful-mermaid
npm i -g @mermaid-js/mermaid-cli   # only needed for --check
```

## Layout
```
beautiful-mermaid/
├── SKILL.md            # agent-facing skill definition
├── README.md           # this file
├── package.json        # engine dependency (beautiful-mermaid)
├── .gitignore          # node_modules/
└── scripts/mermaid.mjs # the CLI
```
SVG output (when no `--svg` path is given) goes to `~/.cache/beautiful-mermaid/latest.svg`.

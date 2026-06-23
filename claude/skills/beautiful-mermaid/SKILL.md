---
name: beautiful-mermaid
description: Use when you need to review, render, or validate a Mermaid diagram from the terminal — renders ASCII/Unicode line-art directly in the TUI, opens a themed SVG in a GUI app, or validates against real mermaid.js (mmdc). Run it before posting a Mermaid block or pasting one into the vault / a PR / docs.
---

# beautiful-mermaid

Review and validate Mermaid diagrams without leaving the terminal. Wraps the
[`beautiful-mermaid`](https://github.com/lukilabs/beautiful-mermaid) library
(pure-JS, no Chromium) for rendering, and keeps `mmdc` (real mermaid.js) as the
opt-in authoritative validator.

## When to use
- **Before posting any Mermaid diagram** — render the ASCII to eyeball structure
  in the TUI (this is what survives Claude Code's text-only output capture).
- **Before pasting into the Obsidian vault, a PR, or docs** — run `--check` so
  you *know* it parses under the same engine GitHub/Obsidian use.
- When a richer, themed picture helps — `--open` an SVG.

## Invocation
```bash
S=~/.claude/skills/beautiful-mermaid/scripts/mermaid.mjs

node "$S" diagram.mmd                 # ASCII (Unicode) in the terminal   [default]
node "$S" -                           # read Mermaid from stdin
node "$S" --code "graph TD;A-->B"     # inline source
node "$S" diagram.mmd --edit          # real mermaid.js — interactive editor (browser)
node "$S" diagram.mmd --view          # real mermaid.js — read-only viewer (browser)
node "$S" diagram.mmd --edit --url    # print the mermaid.live link only (no browser)
node "$S" diagram.mmd --check         # authoritative validate (mmdc) then render
node "$S" diagram.mmd --open          # themed SVG -> open in default GUI app
node "$S" diagram.mmd --open --theme nord
node "$S" diagram.mmd --ascii         # plain +--+ charset (dumb terminals)
node "$S" diagram.mmd --svg out.svg   # write SVG to a path (no window)
```

## How to read the output
- **Flowcharts & sequence diagrams** render faithfully (decision `{…}` nodes show
  as diamonds, loop-backs and edge labels intact).
- **class / state / ER** render structurally (boxes + relationship arrows); member
  lists are simplified. Use `--open` when you need the full picture.

## Important: two parsers, one authoritative
`beautiful-mermaid`'s own parser is **lenient** — it will happily render some
input that real mermaid.js rejects. So ASCII/SVG output ≠ "this will render on
GitHub." Only `--check` (which shells out to `mmdc`) is the real guarantee.
`--edit`/`--view` also use the *real* mermaid.js (in the browser), so they double
as a pixel-faithful visual check of what GitHub/Obsidian will show.

Exit codes: `0` ok · `1` usage/render error · `2` `--check` validation failed.

## Setup (per machine)
This skill vendors its engine via npm. After cloning dotfiles to a new machine:
```bash
npm install --prefix ~/.claude/skills/beautiful-mermaid
```
`--check` additionally needs mermaid-cli: `npm i -g @mermaid-js/mermaid-cli`.

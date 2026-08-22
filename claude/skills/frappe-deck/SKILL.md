---
name: frappe-deck
description: Use when presenting a result, finding, or explanation back to Max as a visual deck instead of chat prose — architecture studies, root-cause writeups, audits, research results, retros, or teaching how something works. Triggers on "slide deck", "slides", "present me", "walk me through", "explain this visually", "report artifact", "presentation". Covers both Claude artifacts and standalone local HTML for agents that cannot publish artifacts.
---

# frappe-deck

HTML slide-deck artifacts in Max's preferred style: Catppuccin Frappe (dark, single-theme), interactive pan/zoom Mermaid, syntax-highlighted code, keyboard nav. The engine (~11KB of CSS/JS boilerplate) lives in `template.html` — never regenerate it, only fill slides.

**Not this skill:** chart-led data reports and dashboards. Those are scrolling pages with light+dark theming and a computed, contrast-validated palette — use `artifact-design` + `dataviz`. frappe-deck is narrative slides on one committed dark theme.

## Workflow

1. Copy `template.html` (same dir as this file) to `<topic>-deck.html`. Publishing as an artifact? Scratchpad is fine. Delivering locally? Write it somewhere Max can reopen it, not a temp dir that gets swept.
2. Set `<title>`. Replace everything between `SLIDES START` / `SLIDES END` markers with your `<section class="slide">` slides. Touch nothing else — CSS tokens, nav bar, and the `<script>` engine stay verbatim.
3. Update the nav-bar `.title` text (deck name) inside `<div id="nav">`.
4. **Pre-render the diagrams to inline SVG. This is mandatory, not an optimization:**
   ```bash
   node ~/.claude/skills/frappe-deck/scripts/prerender.mjs <deck>.html
   ```
   Rendering **is** validation — `mmdc` only emits an SVG if the source parsed, so this replaces the old extract-then-`--check` dance. On any parse error it prints mermaid's real error with line and column, exits `2`, and **leaves the file untouched**; fix the source and re-run. On success every `<pre class="mermaid">` becomes an `<svg>` with a unique id, preceded by its source stashed in a hidden `<pre class="mermaid-src">`. Re-runnable: a second run restores each stash and renders again, so to fix a label or the theme you edit the stash and re-run — no hand-editing SVG. (The stash is a hidden escaped `<pre>`, not an HTML comment, because a `-->` arrow closes a comment early and spills the rest of the source onto the page.)
5. Sanity check the HTML: `grep -c "<section" | grep -c "</section>"` counts match, `<div` count == `</div>` count.
6. Deliver it — pick the lane your runtime supports (see Delivery below).

Why mandatory: a deck whose diagrams are still `<pre class="mermaid">` depends on a mermaid runtime being available *at view time* — the artifact runtime's, or a CDN fetch. Neither is guaranteed, and when both miss, the viewer gets a red "needs network on first load" note where the diagram should be. Pre-rendered SVG has no runtime dependency at all: it works offline, under a strict CSP, in an artifact, and in a `file://` tab.

## Delivery

Step 4 makes both lanes identical as far as diagrams go — the SVG is already in the file, and the template's pan/zoom attaches to whatever SVG it finds in a `.stage`. The CDN fallback loader at the end of the template stays, but on a pre-rendered deck it finds no pending `<pre class="mermaid">` and no-ops. Leave it there as the safety net for a deck that skipped step 4.

**Artifact (Claude Code).** Publish with the Artifact tool, favicon stable per topic. Redeploying the same file path updates in place, but only within the conversation that first published it. From a later session pass the artifact `url` (find it via `action: "list"`), or you publish a duplicate instead of updating.

**Local file (pi, Cursor, any runtime without artifacts).** One thing changes: prepend a doctype when writing the standalone file, or the browser drops into quirks mode and `html,body{height:100%}` collapses the slide layout. The Artifact tool injects this itself, which is why the template omits it:

```html
<!doctype html><meta charset="utf-8">
```

Open it with `start <deck>.html` (Windows) · `open` (macOS) · `xdg-open` (Linux), then tell Max the path so he can reopen it later.

## Slide vocabulary (all styled already)

| Element | Markup |
|---|---|
| Title slide | centered flex div + `.eyebrow` + `h1` + `.sub` + `.kicker mono` |
| Header | `.eyebrow` label, then `h2` with `<span class="n">NN</span>` slide number — title slide is 01 and unnumbered; number content slides from 02; renumber after reordering |
| Two columns | `.cols` (1fr 1fr, stacks on mobile); three cards: `.grid3` |
| Card | `.card good|bad|warn|info` with `h3` + `.sub` |
| Callout | `.callout` (peach) or `.callout red|green|blue` |
| Table | `.tablewrap > table`; `td.num` tabular digits; `tr.hl` red-tint row |
| Chip | `.chip blocker|major|minor|soft|hard` — inline in table `td` or body text, not inside `h3` |
| Hero statement | `.big` with `<em>` for the red word |
| Code | `pre.code > span.cap` caption + `code[data-lang=csharp|lua]` — highlighter is built in (CSP blocks CDN libs); add languages by extending `LANGS` in the engine only if asked |
| Diagram | copy the diagram slide in the template verbatim; put mermaid source inside `pre.mermaid` |

## Mermaid rules

- Keep the `%%{init:...}%%` theme line from the template **verbatim** — it must stay `'theme':'base'`. Mermaid's prebaked themes (`dark`, `default`, `forest`, `neutral`) ignore most `themeVariables`; only `base` is driven by them. A deck on `'theme':'dark'` silently renders stock mermaid grey (`#1f2020` nodes, `#ccc` text) no matter what Frappe values follow it, and step 4 then bakes that in permanently. Verify after rendering: `grep -c 414559 <deck>.html` should be non-zero.
- Inside `pre.mermaid`, escape line breaks as `&lt;br/&gt;` (a literal `<br/>` becomes an HTML tag and vanishes from textContent). Arrows `-->`, `->>`, `-.->`, `-->|label|` stay LITERAL — `-->` is only special inside an already-open HTML comment, so it is safe in a `<pre>`. Do not entity-escape arrows.
- No parentheses, quotes, or `--` inside node labels.
- Accent nodes: `style X fill:#3b2b33,stroke:#e78284` (red) · `#2f3a34/#a6d189` (green) · `#3a382e/#e5c890` (yellow).
- Pan/zoom (wheel, drag, reset, auto-fit) attaches automatically to any `.diagram` block — no JS needed per slide.

## Style rules

- Single-theme Frappe on purpose — do not add a light theme.
- Terse slide copy: fragments fine, every claim keeps its `file:line` cite in `<code>`.
- Content too long for one screen scrolls within the slide (already handled); prefer splitting the slide.
- Big source material? Delegate content extraction to a subagent first (content pack: per-doc bullets, snippets, mermaid specs), then fill slides — keeps this session cheap.

## Common mistakes

- Regenerating the engine "to tweak one color" — edit the token in `:root` instead.
- Literal `<br/>` inside mermaid pre → diagram silently loses line breaks.
- **Publishing before step 4.** A deck that still contains `<pre class="mermaid">` is a deck whose diagrams may not render for the viewer. `grep -c 'class="mermaid"'` should find only the one occurrence inside the fallback loader's own comment.
- Skipping step 4 because "the agent validated earlier" — any label edit can break parsing, and validation and rendering are now the same pass anyway.
- Numbering slides in `h2 .n` but forgetting to renumber after reordering.

## Setup (per machine)

Step 4 needs mermaid-cli (MIT, <https://github.com/mermaid-js/mermaid-cli>), which bundles its own headless Chromium:

```bash
npm i -g @mermaid-js/mermaid-cli      # provides mmdc
```

`mmdc --version` should print 11.x. Same binary the `beautiful-mermaid` skill uses for `--check`, so if that skill works here, this does too.

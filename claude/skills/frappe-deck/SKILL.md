---
name: frappe-deck
description: Use when Max asks for a slide deck, presentation, report artifact, or HTML/CSS/JS deck to present findings — architecture studies, research results, audits, retros. Triggers on "slide deck", "slides", "present me", "report artifact", "presentation".
---

# frappe-deck

HTML slide-deck artifacts in Max's preferred style: Catppuccin Frappe (dark, single-theme), interactive pan/zoom Mermaid, syntax-highlighted code, keyboard nav. The engine (~11KB of CSS/JS boilerplate) lives in `template.html` — never regenerate it, only fill slides.

**Not this skill:** chart-led data reports and dashboards. Those are scrolling pages with light+dark theming and a computed, contrast-validated palette — use `artifact-design` + `dataviz`. frappe-deck is narrative slides on one committed dark theme.

## Workflow

1. Copy `template.html` (same dir as this file) to scratchpad as `<topic>-deck.html`.
2. Set `<title>`. Replace everything between `SLIDES START` / `SLIDES END` markers with your `<section class="slide">` slides. Touch nothing else — CSS tokens, nav bar, and the `<script>` engine stay verbatim.
3. Update the nav-bar `.title` text (deck name) inside `<div id="nav">`.
4. Validate every mermaid block. Extract + unescape in one go (run from the deck's dir):
   ```bash
   node -e "const fs=require('fs'),h=fs.readFileSync(process.argv[1],'utf8');let m,i=0,re=/<pre class=\"mermaid\">([\s\S]*?)<\/pre>/g;while(m=re.exec(h))fs.writeFileSync('d'+(++i)+'.mmd',m[1].replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&'));console.log(i)" <deck>.html
   ```
   then `node ~/.claude/skills/beautiful-mermaid/scripts/mermaid.mjs dN.mmd --check` per file. mmdc "valid" is the gate; the ASCII previewer failing on sequenceDiagram after an init header is a known false alarm. Delete the `.mmd` files after.
5. Sanity check the HTML: `grep -c "<section" | grep -c "</section>"` counts match, `<div` count == `</div>` count.
6. Publish with the Artifact tool (favicon stable per topic). Redeploying the same file path updates in place — but only within the conversation that first published it. From a later session you must pass the artifact `url` (find it via `action: "list"`), or you publish a duplicate instead of updating.

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

- Keep the `%%{init:...}%%` theme line from the template (Frappe-matched colors).
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
- Skipping `--check` because "the agent validated earlier" — any label edit can break parsing.
- Numbering slides in `h2 .n` but forgetting to renumber after reordering.

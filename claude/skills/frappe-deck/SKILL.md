---
name: frappe-deck
description: Use when presenting a result, finding, or explanation back to Max as a visual deck or long-form learning article instead of chat prose - architecture studies, root-cause writeups, audits, research results, retros, or teaching how something works in depth. Triggers on "slide deck", "slides", "present me", "walk me through", "explain this visually", "report artifact", "presentation", "teach me", "deep dive", "explain in depth", "blog style", "article", "write it up", "research and present". Local-first delivery by default (vault artifacts folder + system browser); Claude artifact publish only when explicitly requested.
---

# frappe-deck

Two output formats, one engine philosophy: Catppuccin Frappe (dark, single-theme on
purpose - no light theme in either format), interactive pan/zoom Mermaid, a
syntax-highlighted code block, self-contained HTML with zero network dependency at view
time. **Deck** (`template.html`, ~11KB of CSS/JS boilerplate) is slide-by-slide
presentation. **Article** (`article.html`) is a scrolling long-form learning document
with a scroll-spy table-of-contents sidebar, sidenotes, footnotes, and interactive
widgets. Both engines live alongside this file - never regenerate either one, only fill
content between their markers.

## Step 0 - pick the format

| Format | Pick it when |
|---|---|
| **Article** (`article.html`) - default for learning | Max wants to learn a dense topic end to end: "teach me", "deep dive", "explain in depth", "write it up", "research and present". Scrolling document, TL;DR, layered explanations, cited sources, retrieval checkpoints. |
| **Deck** (`template.html`) - presenting results | Presenting a finished result, finding, or explanation back to Max at a glance: architecture studies, root-cause writeups, audits, retros. Narrative slides, one screen at a time. |
| **Not this skill** | Chart-led data reports and dashboards - scrolling pages with light+dark theming and a computed, contrast-validated palette. Use `artifact-design` + `dataviz` instead. |

Max's vault records "slides, not scroll" as his historical reporting preference - that
preference is about presenting *results*, not about learning. Article is a deliberate
second mode for the learning case, not a drift from the recorded preference. Pick by
task shape (learn vs. present), don't default to deck out of habit.

## Delivery

Local-first by default for both formats. Prerendering (see each workflow below) makes
the two delivery lanes identical as far as diagrams go - the SVG is already in the file,
and the pan/zoom attaches to whatever SVG it finds in a `.stage`. The CDN fallback
loader at the end of each template stays as the safety net for a file that skipped the
prerender step; on a prerendered file it finds nothing pending and no-ops.

- **Default: local, in the vault.** Write the finished file(s) into
  `$OBSIDIAN_VAULT/05.Wiki/artifacts/<yyyy-mm-dd>-<slug>.html` (article: plus a
  full-content `.md` companion at the same slug - skeleton in Article workflow below).
  Prepend the doctype (below), open the `.html` in the system browser -
  `start <file>.html` (Windows) / `open` (macOS) / `xdg-open` (Linux) - and report every
  path you wrote to Max so he can reopen it later.
- **No vault on this machine.** Fall back to a stable, reopenable location: a
  project-local `docs/artifacts/`, or `~/frappe-articles/` outside a repo. Never a
  scratchpad or temp dir - Max needs to come back to the file.
- **Doctype-prepend rule.** Neither template ships a `<!doctype>` - the Artifact tool
  injects one itself, which is why the templates omit it. Writing a local file yourself,
  you must prepend one, or the browser drops into quirks mode and `html,body{height:100%}`
  collapses the layout (slide stage or article shell, same failure mode):
  ```html
  <!doctype html><meta charset="utf-8">
  ```
- **Claude artifact publish - opt-in only.** Publish to Claude's artifact host only when
  Max explicitly asks ("publish it", "as an artifact") - the default is local. When he
  does: use the Artifact tool, favicon stable per topic. Redeploying the same file path
  updates in place, but only within the conversation that first published it. From a
  later session pass the artifact `url` (find it via `action: "list"`), or you publish a
  duplicate instead of updating.

## Deck workflow

1. Copy `template.html` (same dir as this file) to `<topic>-deck.html`. Publishing as an
   artifact? Scratchpad is fine. Delivering locally? See Delivery above.
2. Set `<title>`. Replace everything between `SLIDES START` / `SLIDES END` markers with
   your `<section class="slide">` slides. Touch nothing else - CSS tokens, nav bar, and
   the `<script>` engine stay verbatim.
3. Update the nav-bar `.title` text (deck name) inside `<div id="nav">`.
4. **Pre-render the diagrams to inline SVG. This is mandatory, not an optimization:**
   ```bash
   node ~/.claude/skills/frappe-deck/scripts/prerender.mjs <deck>.html
   ```
   Rendering **is** validation - `mmdc` only emits an SVG if the source parsed, so this
   replaces the old extract-then-`--check` dance. On any parse error it prints mermaid's
   real error with line and column, exits `2`, and **leaves the file untouched**; fix the
   source and re-run. On success every `<pre class="mermaid">` becomes an `<svg>` with a
   unique id, preceded by its source stashed in a hidden `<pre class="mermaid-src">`.
   Re-runnable: a second run restores each stash and renders again, so to fix a label or
   the theme you edit the stash and re-run - no hand-editing SVG. (The stash is a hidden
   escaped `<pre>`, not an HTML comment, because a `-->` arrow closes a comment early and
   spills the rest of the source onto the page.)
5. Sanity check the HTML - count occurrences, not matching lines (`grep -c` counts lines,
   and one line often holds several tags): `grep -o '<section' <deck>.html | wc -l` equals
   `grep -o '</section>' <deck>.html | wc -l`, and the same for `<div` / `</div>`. Count
   `<div` only - the engine's script comments contain unpaired literal tags (`<pre>`,
   `<details>`, `<p>`), so improvised balance-greps on other tags will misreport; the
   engine contributes a balanced set of divs.
6. Deliver it - see Delivery above.

Why mandatory: a deck whose diagrams are still `<pre class="mermaid">` depends on a
mermaid runtime being available *at view time* - the artifact runtime's, or a CDN fetch.
Neither is guaranteed, and when both miss, the viewer gets a red "needs network on first
load" note where the diagram should be. Pre-rendered SVG has no runtime dependency at
all: it works offline, under a strict CSP, in an artifact, and in a `file://` tab.

## Article workflow

1. Copy `article.html` (same dir as this file) to `<topic>-article.html`. Same
   delivery-location rule as decks - see Delivery above.
2. Set `<title>` and fill the `<header class="art">` block (`.eyebrow`, `h1`,
   `.standfirst`). Replace everything between `ARTICLE START` / `ARTICLE END` markers
   with your content, following the Authoring guide below. Touch nothing else - CSS
   tokens and the `<script>` engine stay verbatim; the engine builds the MoC sidebar and
   reading time from your `h2`/`h3` headings automatically, zero nav upkeep.
3. **Pre-render diagrams to inline SVG - mandatory, same command and reasoning as decks**
   (`prerender.mjs` targets `<pre class="mermaid">` regardless of which template it's
   in):
   ```bash
   node ~/.claude/skills/frappe-deck/scripts/prerender.mjs <topic>-article.html
   ```
   The script also guards against duplicate SVG ids across multiple diagrams in one
   file - inlined mermaid SVGs share one DOM id namespace, so a repeated
   `<marker id="...">` would make a later diagram silently borrow the first diagram's
   markers. This runs automatically inside `prerender.mjs`; on a collision it exits `2`
   naming the offending id, no separate manual check needed.
4. Sanity check the HTML - count occurrences, not matching lines:
   `grep -o '<div' <topic>-article.html | wc -l` equals
   `grep -o '</div>' <topic>-article.html | wc -l`. Count `<div` only - the engine's
   script comments contain unpaired literal tags (`<pre>`, `<details>`, `<p>`), so
   improvised balance-greps on other tags will misreport; the engine contributes a
   balanced set of divs. Then `grep -c 'class="mermaid"'`
   finds only the fallback-loader's own comment occurrence; if the article has diagrams,
   `grep -c 414559 <topic>-article.html` is non-zero (same Frappe-token check as decks -
   see Mermaid rules below).
5. Author the companion `.md` - full content, not a stub. Frontmatter:
   ```yaml
   ---
   type: learning-artifact
   title: "<Title>"
   created: <yyyy-mm-dd>
   source: claude-code/frappe-deck
   topics: [<topic>, ...]
   tags: [type/artifact]
   artifact: "[[<yyyy-mm-dd>-<slug>.html]]"
   ---
   ```
   Directly under the frontmatter:
   ```markdown
   > [!tip] Full interactive version
   > [Open in browser](file:///C:/ObsidianVaults/05.Wiki/artifacts/<...>.html) -
   > pan/zoom diagrams, step-through code, labs. Or [[<...>.html|open in Obsidian]].
   ```
   Three link forms, three jobs: the frontmatter wikilink is dataview-queryable and
   survives renames/moves; the `file:///` markdown link is one click to the system
   browser with full JS (forward slashes, triple slash; regenerate if the file moves);
   the body wikilink is a graph edge plus Obsidian's open-in-default-app fallback. Then
   the full article content: TL;DR, scope contract, every section, code fences, callouts
   as `> [!note]`-family, review questions, sources. Diagrams as mermaid fences by
   default (source is already stashed in the html by `prerender.mjs`; Obsidian renders
   fences natively; theme follows the vault, not Frappe - accepted). Exact-Frappe-fidelity
   alternative only when Max asks: export `.svg` files next to the pair and embed with
   `![[...]]`. Interactive features degrade to their static equivalent (step-throughs:
   all steps shown; labs: key parameter values tabulated). `[[wikilinks]]` into the wiki
   for every entity/concept the article touches - unresolved links are a feature (red
   TODO nodes), not something to fix.
6. Wiki bookkeeping:
   - Add the artifact to `05.Wiki/index.md` under a `## Artifacts` section (create if
     missing): wikilink + one-line summary, refresh counts.
   - Append a `log.md` entry: `## [<date>] artifact | <Title>` with created/updated
     pages.
   - Interlink: relevant concept/entity pages get a link to the artifact note where it
     genuinely adds value - do not spam.
7. Deliver - see Delivery above (writes both files, opens the `.html`, reports both
   paths).

## Authoring guide (article)

The full pedagogy layer. Grounded in learning-science research (effect sizes and
sources in the design spec's references section) - treat it as rules, not a vibe.

### Skeleton (in order)

1. TL;DR - answer-first: the conclusion plus 3-5 load-bearing claims, each anchor-linking
   to the section that proves it.
2. Scope contract - three rows: Covers / Assumes you know / Not covered (with pointers
   for the assumed parts).
3. Advance organizer - ONE diagram of the whole mechanism, early. Every later section
   refers back to it; prefer one accumulating model over a fresh diagram per section.
4. Sections - see the recipe below.
5. The rule restated literally - after the analogies and examples, state the precise
   general mechanism in plain technical language.
6. Review questions - a copy-pasteable list of the retrieval questions used in the
   `.check` blocks, labeled "review these in a week".
7. Sources - full URL list; footnote targets live here.

### Section recipe (default shape, adapt with judgment - not a straitjacket)

- Prequestion (`<details class="predict">`): one question the reader will likely get
  wrong, asked BEFORE the explanation. Factual beats conceptual for prequestions.
- Concrete case first: a specific, real scenario ("this MonoBehaviour stutters at frame
  3"), then generalize. Concrete -> bridge -> abstract wins on transfer (concreteness
  fading).
- Worked example with subgoal labels: split code into goal-named groups ("Cache the
  reference", "Guard re-entry", "Apply the impulse"). Reuse the same label vocabulary
  across every example in the article and echo it in section anchors.
- Optional faded variant: same pattern with 1-2 pieces blanked (click-to-reveal), then a
  bare challenge.
- Retrieval checkpoint (`.check` blocks): 2-3 questions from memory, content-directed
  only - never "do you understand?" (metacognitive prompts measurably underperform
  content-directed ones).

### Explanation rules

- **ADEPT ordering** for each new concept: Analogy, Diagram, Example, Plain English,
  Technical definition. Never put a formula or API signature before a plain-English
  sentence of the same idea.
- **Every analogy needs a mapping table AND a breaks-down line.** Source -> target
  mapping table, then a final "breaks down when ..." sentence, then restate the idea
  literally - an analogy left as the last word improves inference but measurably
  degrades factual recall.
- **Progressive disclosure, not progressive repetition.** ELI5 and background go in
  collapsed `<details>`, skippable in one click, adding information the main path does
  not repeat. Never retell the same idea three times in a row - unskippable scaffolding
  actively harms readers who already know it (expertise reversal).
- **Integrated annotation, never a legend.** Labels live inside diagrams (SVG `<text>`);
  explanations sit beside the exact line (sidenotes, step captions). Never "see the code
  above" - that's split attention, and integrating carries a large measured effect.
- Prose introduces every figure before it appears; figures themselves carry near-zero
  caption text.
- **Show the bug first** where a misconception is common: ship the plausible-but-wrong
  version, let the reader find the flaw in a predict block, then diagnosis + fix as a
  `data-diff` block. Never ship broken code without the reveal attached.
- One idea per paragraph, 3-5 sentences, lead sentence carries the point - the lead
  sentences alone should read as an outline. Questions make good `h2`s.
- Gloss jargon inline at first use.
- **No decorative content.** No mood images, no fun facts, no asides that don't carry a
  load-bearing idea - seductive details measurably hurt learning, they don't just waste
  space.
- Citations: every factual claim gets a sidenote citation next to it; full URLs
  collected in Sources. `file:line` cites in `<code>`, same as decks.
- Widgets: one concept per widget. Slider labels are bare domain nouns ("entities",
  "cost/entity" - never "adjust the ..."). Controls sit below the figure. Reach for small
  multiples first; add a slider only when the parameter space is genuinely continuous.
  Share concept colors between prose, diagram, and code.

### Article markup vocabulary

| Form | Markup |
|---|---|
| Sidenote | `<span class="sn">...</span>` right after the text it annotates - engine numbers it, emits `<sup class="sn-ref">` + `<span class="snb">` (floats right into the gutter on wide viewports, inline block with a left border on narrow). **Inline content only, 1-3 sentences - no block elements** (lists, `pre`, tables). If it needs a code block, it's a paragraph, not a sidenote. Never place a `span.sn` inside a `.cols` grid - the gutter float has nothing to float against and the note lands wrong. A sidenote alongside a `.wide` block can collide with it; prefer plain paragraphs next to breakout blocks. |
| Footnote (full citation) | pandoc/DPUB-ARIA shape: `<a id="fnref1" href="#fn1" role="doc-noteref"><sup>1</sup></a>` in the body, `<section role="doc-endnotes"><ol><li id="fn1">text <a href="#fnref1" role="doc-backlink" aria-label="Back to reference 1">&#8617;</a></li></ol></section>` at the end. `li:target` gets a yellow-tint flash from the engine CSS on click-through. |
| Prequestion | `<details class="predict"><summary>Before reading: ...?</summary>reveal</details>` (mauve accent). |
| Retrieval checkpoint | `<details class="check"><summary>question</summary>answer</details>` (green accent). Group exclusively with the native `<details name="...">` attribute (one open at a time) when a set of checks should behave like a radio group - zero JS, browser-native. |
| Typed callout | `<div class="callout def|tip|bug"><span class="ctitle">LABEL</span>...</div>` - `.def` (blue, definition), `.tip` (green, technique), `.bug` (red, gotcha). Plain `.callout` with no type class is the peach "warn" default (same class decks already use); the `.red`/`.green`/`.blue` generic accent variants from decks still work too. `.ctitle` is the small-caps label line, add it on any variant. |
| Concept color | `<span class="c1">term</span>` .. `.c4` - 4 accent classes (blue/green/peach/mauve) binding prose mentions to the same entity in a diagram or code block. One color per entity, max 4 total for the whole article, everything else stays neutral. |
| Line-highlighted code | `<pre class="code" data-hl="3-5,9">` - non-highlighted lines dim to ~0.38 opacity, highlighted lines get a 2px accent bar. |
| Step-through code | `data-steps="1-4|6-9|11-14" data-captions="A|B|C"` on the same `pre.code` - one snippet, N steps; engine renders prev/next controls outside the scroller, binds arrow keys and `[`/`]`. The keys only fire while the block itself has focus (click it or tab to it); the buttons always work. |
| Diff code | `data-diff` on `pre.code`; lines starting `-`/`+` get a real gutter sign (not `::before`, for a11y) plus a tint. See Common mistakes for the bare-sign gotcha. |
| Lab (interactive widget) | `.lab` div with `input[name]` controls and `data-out`/`data-attr`/`data-class`/`data-style` expressions on the elements they drive; `data-scrub="name"` on a `<b>` for a drag-to-adjust number - it requires a matching `input[name]` in the same `.lab` (mark that input `hidden` if only the scrub should show). Expressions compile once per lab (`new Function`) with the input names as arguments; labs are islands, one never mutates anything outside its own `.lab` block. |
| Breakout width | `.wide` (spans body + gutter) or `.full` (spans everything) on a block that needs more than the 66ch body measure. |
| Diagram | `.diagram` block - same markup as decks: mermaid source in `pre.mermaid`, pre-render before delivery, pan/zoom attaches automatically. One behaviour differs: article diagrams zoom with **ctrl+wheel** (plain wheel scrolls the page); decks keep plain-wheel zoom. Keep the `.dhint` wording in sync with that. |
| Hover preview | Automatic for every internal `a[href^="#"]` link inside the article body - nothing to mark up. |

### Not built, do not relitigate

- Tabs - hash collision with the ToC/footnotes, pure-CSS tabs fail a11y; `<details>` already covers the same job.
- Editable-code-that-reruns - caret-position-vs-rehighlight is a permanent bug class, not worth chasing.
- JS REPL - works fine under the CSP but teaches nothing for C#/Unity content.
- WASM runtimes - the .NET runtime alone is ~11-15MB against a 16MB artifact cap, before base64's +33%.
- CSS scroll-driven progress, CSS anchor positioning, `popover="hint"` - each still needs the same fallback code as the feature it replaces, in 2026.

### Pre-delivery checklist (article)

Extends the mechanical checks in Article workflow step 4. Before delivering, confirm:

- Every analogy has its mapping table and its "breaks down when ..." line.
- Every section ends with a content-directed checkpoint - never "do you understand?".
- No formula or API signature appears before its plain-English sentence.
- Every TL;DR claim anchor-links to the section that proves it, and the lead sentences
  alone read as an outline.
- At most 4 concept colors, one entity each, consistent across prose, diagrams, and code.
- Big source material handled per Style rules (delegate a content pack to a subagent
  first, then fill) - same rule as decks, not repeated here.

## Slide vocabulary (all styled already)

| Element | Markup |
|---|---|
| Title slide | centered flex div + `.eyebrow` + `h1` + `.sub` + `.kicker mono` |
| Header | `.eyebrow` label, then `h2` with `<span class="n">NN</span>` slide number - title slide is 01 and unnumbered; number content slides from 02; renumber after reordering |
| Two columns | `.cols` (1fr 1fr, stacks on mobile); three cards: `.grid3` |
| Card | `.card good|bad|warn|info` with `h3` + `.sub` |
| Callout | `.callout` (peach) or `.callout red|green|blue` |
| Table | `.tablewrap > table`; `td.num` tabular digits; `tr.hl` red-tint row |
| Chip | `.chip blocker|major|minor|soft|hard` - inline in table `td` or body text, not inside `h3` |
| Hero statement | `.big` with `<em>` for the red word |
| Code | `pre.code > span.cap` caption + `code[data-lang=csharp|lua]` - highlighter is built in (CSP blocks CDN libs); add languages by extending `LANGS` in the engine only if asked. See **Code blocks** below |
| Diagram | copy the diagram slide in the template verbatim; put mermaid source inside `pre.mermaid` |

## Code blocks

- **Indent with 2 spaces, never 4 or a tab.** Slides are ~62 characters of comfortable width at 13.5px mono; 4-space indents push nested code into horizontal scrolling for no gain. Re-indent snippets copied from a repo - the slide is a different medium from the file.
- **Keep real line breaks.** One statement per line; never fold a block onto one line to save vertical space. If a snippet does not fit the slide, cut lines from it rather than reflowing it - an elided body (`// ...`) reads fine, a wrapped one does not.
- **Break long signatures at the parameter list**, continuation indented one level (2 spaces):
  ```
  public static Vector3 Offset(
    float t, float maxSide, float maxDip) => ...
  ```
- **Escape `<`, `>`, `&` in the source** as `&lt;` `&gt;` `&amp;`. The block sits in HTML, so a raw `List<Func<bool>>` is parsed as markup before any script sees it.
- The highlighter re-escapes on its own pass, so generics survive. That was **not** true before 2026-08-22 - it escaped only the matched tokens and injected the gaps raw, which made every generic argument vanish from the rendered slide. If you see a type lose its `<T>`, the deck predates the fix; re-copy the engine from `template.html`.
- **Do not style the block `<code>`.** `pre.code > code` is reset in the template (`white-space:pre`, inherited font and colour, no chip box). The inline-chip rule is scoped `:not(pre) > code` precisely so it cannot reach block code - a bare `code{}` selector reintroduces `white-space:nowrap` and collapses every snippet to a single line.
- **Article code blocks can additionally use line features** - `data-hl`, `data-steps`/`data-captions`, `data-diff` - see the article markup vocabulary table above for the exact attributes. Deck code blocks don't need them (a whole slide is already one "step").

## Mermaid rules

- Keep the `%%{init:...}%%` theme line from the template **verbatim** - it must stay `'theme':'base'`. Mermaid's prebaked themes (`dark`, `default`, `forest`, `neutral`) ignore most `themeVariables`; only `base` is driven by them. A file on `'theme':'dark'` silently renders stock mermaid grey (`#1f2020` nodes, `#ccc` text) no matter what Frappe values follow it, and the prerender step then bakes that in permanently. Verify after rendering: `grep -c 414559 <file>.html` should be non-zero.
- Inside `pre.mermaid`, escape line breaks as `&lt;br/&gt;` (a literal `<br/>` becomes an HTML tag and vanishes from textContent). Arrows `-->`, `->>`, `-.->`, `-->|label|` stay LITERAL - `-->` is only special inside an already-open HTML comment, so it is safe in a `<pre>`. Do not entity-escape arrows.
- No parentheses, quotes, or `--` inside node labels.
- Accent nodes: `style X fill:#3b2b33,stroke:#e78284` (red) · `#2f3a34/#a6d189` (green) · `#3a382e/#e5c890` (yellow) · `style X fill:#2f3846,stroke:#8caaee` (blue) · `#3d3229/#ef9f76` (peach) · `#382f3d/#ca9ee6` (mauve). Blue/peach/mauve are the diagram-side match for the article's concept colors `c1`/`c3`/`c4` (green is `c2`) - use them to bind a node to the same entity in prose and code.
- Pan/zoom (drag, reset, auto-fit) attaches automatically to any `.diagram` block - no JS needed per slide or section. Zoom is plain wheel on a deck, **ctrl+wheel in an article** (a scrolling document must keep plain wheel for the page).

## Style rules

- Single-theme Frappe on purpose - do not add a light theme.
- Terse copy: fragments fine, every claim keeps its `file:line` cite in `<code>`.
- Content too long for one screen scrolls within the slide/section (already handled); on a deck, prefer splitting the slide.
- Big source material? Delegate content extraction to a subagent first (content pack: per-doc bullets, snippets, mermaid specs), then fill slides/sections - keeps this session cheap.

### Media rules

- Vector art: paste raw inline `<svg>`, never data-URI it.
- Raster (screenshots): WebP/AVIF as data URIs, never PNG - real binary budget ~12MB (base64 adds +33% against the 16MB artifact cap).
- `loading="lazy" decoding="async"` on every data-URI image.

## Common mistakes

- Regenerating the engine "to tweak one color" - edit the token in `:root` instead.
- Literal `<br/>` inside mermaid pre -> diagram silently loses line breaks.
- **Publishing before the prerender step.** A file that still contains `<pre class="mermaid">` is a file whose diagrams may not render for the viewer. `grep -c 'class="mermaid"'` should find only the one occurrence inside the fallback loader's own comment.
- Skipping the prerender step because "the agent validated earlier" - any label edit can break parsing, and validation and rendering are now the same pass anyway.
- Numbering slides in `h2 .n` but forgetting to renumber after reordering.
- Pasting a snippet straight from a repo at its original 4-space indent. Re-indent to 2 (see **Code blocks**) - the slide/section is narrower than the file.
- In `data-diff` blocks, context lines must not start with a bare `+` or `-` (e.g. `++i;` at column 0) - the sign parser will eat the first character. Indent the line or restructure the snippet.
- A sidenote with block content (a list, a `pre`, a table) - sidenotes are inline-only, 1-3 sentences; if it needs a code block, it's a paragraph.
- A formula or API signature before its plain-English sentence - breaks ADEPT ordering.
- An analogy without a source->target mapping table and a "breaks down when ..." line.
- Decorative images - mood shots, fun facts, anything that isn't load-bearing.
- Three sequential retellings of the same idea instead of progressive disclosure in a collapsed `<details>` - unskippable repetition harms readers who already know the material.
- A bare `h2` selector (or any bare tag selector) in custom CSS - both templates scope every rule (`article h2`, `.card h3`, etc.) precisely so a stray override can't leak into content it wasn't meant for.

## Setup (per machine)

The prerender step needs mermaid-cli (MIT, <https://github.com/mermaid-js/mermaid-cli>), which bundles its own headless Chromium:

```bash
npm i -g @mermaid-js/mermaid-cli      # provides mmdc
```

`mmdc --version` should print 11.x. Same binary the `beautiful-mermaid` skill uses for `--check`, so if that skill works here, this does too.

### One-time Obsidian setup

Walk Max through this once, at the first article delivery:

- Settings -> Files and links -> "Detect all file extensions" ON (so the `.html`
  companion is visible and linkable in Obsidian).
- Exclude `05.Wiki/artifacts/` from obsidian-linter - it rewrites frontmatter on save
  and can mangle the artifact wikilink.

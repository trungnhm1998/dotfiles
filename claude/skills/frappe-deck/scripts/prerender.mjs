#!/usr/bin/env node
// Pre-render every <pre class="mermaid"> in a frappe deck to inline SVG, in place.
// Rendering IS validation: mmdc only emits an SVG if the source parsed, so this
// replaces the separate --check pass. Nothing is written unless every diagram renders.
//
//   node prerender.mjs <deck.html> [--out other.html]
//
// Re-runnable: each diagram's source is stashed in a hidden <pre class="mermaid-src">
// beside its SVG, so a later run restores it and re-renders. Edit the stash (or the
// theme header) and run again. The stash is NOT an HTML comment: mermaid's `-->`
// arrows close a comment early and spill the rest of the source onto the page.
//
// The stash also keeps both mermaid runtimes off the diagram — the template's CDN
// fallback and the Claude artifact renderer both select `pre.mermaid`, which no
// longer matches once rendered.
//
// Exit: 0 ok · 1 usage/IO · 2 a diagram failed to render.

import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const args = process.argv.slice(2);
const src = args.find((a) => !a.startsWith("--"));
const out = args.includes("--out") ? args[args.indexOf("--out") + 1] : src;
if (!src) {
  console.error("usage: prerender.mjs <deck.html> [--out other.html]");
  process.exit(1);
}

const unescape = (s) =>
  s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
const escape = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const BLOCK = /<pre class="mermaid">([\s\S]*?)<\/pre>/g;
const DONE =
  /<pre class="mermaid-src" hidden>([\s\S]*?)<\/pre>\s*<svg[\s\S]*?<\/svg>/g;

let html = readFileSync(src, "utf8");

// Unwind any previous render first, so a deck is always re-renderable.
const restored = (html.match(DONE) || []).length;
if (restored) {
  html = html.replace(DONE, (_, stashed) => `<pre class="mermaid">${stashed}</pre>`);
}

const blocks = [...html.matchAll(BLOCK)];
if (!blocks.length) {
  console.log('no <pre class="mermaid"> blocks found — nothing to render');
  process.exit(0);
}
if (restored) console.log(`restored ${restored} previously rendered diagram(s)\n`);

const work = mkdtempSync(join(tmpdir(), "frappe-deck-"));
const rendered = [];

try {
  blocks.forEach((m, i) => {
    const id = `mmd-${i + 1}`;
    const source = unescape(m[1]).trim();
    const mmd = join(work, `${id}.mmd`);
    const svgPath = join(work, `${id}.svg`);
    writeFileSync(mmd, source, "utf8");

    // -I gives each SVG a unique id so mermaid's scoped <style> rules don't
    // collide once several are inlined into one page. -b transparent lets the
    // .diagram card background show through.
    // shell:true is required on Windows (mmdc resolves to a .cmd), so quote the
    // paths ourselves — shell:true concatenates args without escaping them.
    const q = (s) => `"${s}"`;
    const r = spawnSync(
      "mmdc",
      ["-i", q(mmd), "-o", q(svgPath), "-b", "transparent", "-I", id, "-q"],
      { shell: true, encoding: "utf8" }
    );

    let svg;
    try {
      svg = readFileSync(svgPath, "utf8");
    } catch {
      console.error(`\n✗ diagram ${i + 1} failed to render:\n`);
      console.error((r.stderr || r.stdout || "mmdc produced no output").trim());
      console.error(`\nsource:\n${source}`);
      process.exit(2);
    }

    // Strip the XML prolog/doctype — invalid inside an HTML body.
    svg = svg
      .replace(/^﻿/, "")
      .replace(/<\?xml[\s\S]*?\?>\s*/, "")
      .replace(/<!DOCTYPE[\s\S]*?>\s*/i, "")
      .trim();

    rendered.push(
      `<pre class="mermaid-src" hidden>${escape(source)}</pre>\n${svg}`
    );
    console.log(`✓ ${id} rendered (${(svg.length / 1024).toFixed(1)} KB)`);
  });
} finally {
  rmSync(work, { recursive: true, force: true });
}

let n = 0;
html = html.replace(BLOCK, () => rendered[n++]);

// Inline SVGs share one DOM id namespace: a duplicate <marker>/<gradient> id makes
// later diagrams silently borrow the first diagram's defs. -I should prevent this;
// guard anyway.
{
  const svgIds = (html.match(/<svg[\s\S]*?<\/svg>/g) || [])
    .join("")
    .match(/(?<![\w-])id="([^"]+)"/g) || [];
  const seenIds = new Set();
  const dups = new Set();
  for (const raw of svgIds) {
    const id = raw.slice(4, -1);
    if (seenIds.has(id)) dups.add(id);
    else seenIds.add(id);
  }
  if (dups.size) {
    console.error(
      `\n✗ duplicate SVG id(s) across diagrams: ${[...dups].join(", ")}\n` +
        "  Later diagrams would render with the first diagram's defs. File left untouched."
    );
    process.exit(2);
  }
}

writeFileSync(out, html, "utf8");

// The Frappe palette only lands when the source header says 'theme':'base' —
// mermaid's prebaked themes ignore themeVariables. Catch that here rather than
// letting a grey deck ship.
const inSvg = (html.match(/<svg[\s\S]*?<\/svg>/g) || []).join("");
if (!inSvg.includes("#414559")) {
  console.warn(
    "\n⚠ rendered SVGs contain no Frappe surface color (#414559).\n" +
      "  The %%{init}%% header is probably on 'theme':'dark' — only 'theme':'base'\n" +
      "  honours themeVariables. Fix the header and re-run."
  );
}

console.log(`\n${rendered.length} diagram(s) inlined -> ${out}`);

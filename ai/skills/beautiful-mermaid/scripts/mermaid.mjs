#!/usr/bin/env node
/**
 * beautiful-mermaid — terminal CLI for reviewing & validating Mermaid diagrams.
 *
 * Engine: the `beautiful-mermaid` npm library (pure JS, no Chromium) renders
 * ASCII/Unicode for the terminal and themed SVG. `mmdc` (real mermaid.js) is
 * kept ONLY as an opt-in authoritative validator, because beautiful-mermaid's
 * own parser is lenient and will happily render things GitHub/Obsidian reject.
 *
 *   node mermaid.mjs <file.mmd>            ASCII (Unicode) to the terminal  [default]
 *   node mermaid.mjs -                     read Mermaid from stdin
 *   node mermaid.mjs --code "graph TD;A-->B"   inline source
 *   node mermaid.mjs <file> --open         themed SVG -> open in default app
 *   node mermaid.mjs <file> --check        validate via mmdc, then render
 *   node mermaid.mjs <file> --ascii        plain ASCII charset (no Unicode)
 *   node mermaid.mjs <file> --open --theme nord
 *
 * Exit codes: 0 ok · 1 usage/render error · 2 validation (--check) failed.
 */

import { readFileSync, writeFileSync, mkdirSync, unlinkSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { deflateSync } from 'node:zlib';

const SELF = dirname(fileURLToPath(import.meta.url));
const CACHE_DIR = join(homedir(), '.cache', 'beautiful-mermaid');
const DEFAULT_THEME = 'github-light';

// ---------- arg parsing (tiny, no deps) ----------
function parseArgs(argv) {
  const o = { open: false, edit: false, view: false, url: false, check: false, ascii: false, theme: DEFAULT_THEME, svgOut: null, code: null, input: null, help: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case '-h': case '--help': o.help = true; break;
      case '--open': o.open = true; break;
      case '--edit': o.edit = true; break;
      case '--view': o.view = true; break;
      case '--url': o.url = true; break;
      case '--check': o.check = true; break;
      case '--ascii': o.ascii = true; break;
      case '--theme': o.theme = argv[++i]; break;
      case '--svg': o.svgOut = argv[++i]; break;
      case '--code': o.code = argv[++i]; break;
      case '-': o.input = '-'; break;
      default:
        if (a.startsWith('--')) die(`unknown flag: ${a}  (try --help)`, 1);
        else if (o.input == null) o.input = a;
        else die(`unexpected argument: ${a}`, 1);
    }
  }
  return o;
}

function die(msg, code = 1) { process.stderr.write(`✗ ${msg}\n`); process.exit(code); }

const HELP = `beautiful-mermaid — review & validate Mermaid in the terminal

USAGE
  node mermaid.mjs <file.mmd>          ASCII (Unicode) to terminal      [default]
  node mermaid.mjs -                   read source from stdin
  node mermaid.mjs --code "<mermaid>"  inline source
  node mermaid.mjs <src> --edit        open mermaid.live editor (real mermaid.js)
  node mermaid.mjs <src> --view        open mermaid.live viewer (read-only)
  node mermaid.mjs <src> --edit --url  print the mermaid.live link (don't open)
  node mermaid.mjs <src> --open        themed SVG -> open in default app (offline)
  node mermaid.mjs <src> --check        authoritative validate (mmdc) then render
  node mermaid.mjs <src> --ascii        plain ASCII charset (no Unicode boxes)
  node mermaid.mjs <src> --theme <name> SVG theme for --open (default ${DEFAULT_THEME})
  node mermaid.mjs <src> --svg <path>   write SVG to <path> (no window)

NOTES
  • Default ASCII is instant (pure JS). --check spins up mmdc/Chromium (~1-2s)
    and is the only "will this render on GitHub/Obsidian" guarantee.
  • --edit/--view use real mermaid.js in the browser; the diagram rides in the
    URL fragment (never sent to the server). --open/SVG and ASCII are offline.
  • SVG themes: zinc-light/dark, tokyo-night(-storm/-light), catppuccin-mocha/latte,
    nord(-light), dracula, github-light/dark, solarized-light/dark, one-dark.`;

// ---------- load the engine (resolves <skill>/node_modules) ----------
async function loadEngine() {
  try {
    return await import('beautiful-mermaid');
  } catch {
    die(`engine 'beautiful-mermaid' not installed.\n  Run:  npm install --prefix "${SELF}/.."`, 1);
  }
}

// ---------- read the Mermaid source ----------
function readSource(o) {
  if (o.code != null) return o.code;
  if (o.input && o.input !== '-') {
    try { return readFileSync(o.input, 'utf8'); }
    catch (e) { die(`cannot read file: ${o.input} (${e.code || e.message})`, 1); }
  }
  // stdin: explicit '-' or piped input
  if (o.input === '-' || !process.stdin.isTTY) {
    try { return readFileSync(0, 'utf8'); }
    catch { die('no input on stdin', 1); }
  }
  process.stderr.write(HELP + '\n');
  process.exit(1);
}

// ---------- authoritative validation via mmdc ----------
function validateWithMmdc(source) {
  const tmpIn = join(CACHE_DIR, `check-${process.pid}.mmd`);
  const tmpOut = join(CACHE_DIR, `check-${process.pid}.svg`);
  mkdirSync(CACHE_DIR, { recursive: true });
  writeFileSync(tmpIn, source);
  const r = spawnSync('mmdc', ['-i', tmpIn, '-o', tmpOut, '--quiet'], { encoding: 'utf8', shell: process.platform === 'win32' });
  // cleanup
  for (const f of [tmpIn, tmpOut]) { try { unlinkSync(f); } catch {} }

  if (r.error && r.error.code === 'ENOENT') {
    die('--check needs mmdc (mermaid-cli) on PATH:  npm i -g @mermaid-js/mermaid-cli', 1);
  }
  if (r.status === 0) { process.stderr.write('✓ valid (mermaid.js)\n'); return; }

  // extract the clean parse error, suppress puppeteer stack
  const err = (r.stderr || '') + (r.stdout || '');
  const line = err.split('\n').find(l => /Parse error on line \d+/i.test(l))
            || err.split('\n').find(l => /^\s*Error:/.test(l))
            || err.split('\n').filter(Boolean)[0]
            || 'unknown error';
  const detail = err.split('\n').find(l => /Expecting|got '|Unrecognized/.test(l));
  process.stderr.write(`✗ validation failed: ${line.trim()}\n`);
  if (detail) process.stderr.write(`  ${detail.trim()}\n`);
  process.exit(2);
}

// ---------- open a file OR url in the OS default app ----------
function openInApp(target) {
  const p = process.platform;
  const [cmd, args] = p === 'darwin' ? ['open', [target]]
    : p === 'win32' ? ['cmd', ['/c', 'start', '', target]]
    : ['xdg-open', [target]];
  const r = spawnSync(cmd, args, { stdio: 'ignore' });
  if (r.error) die(`could not open ${target}: ${r.error.message}`, 1);
}

// ---------- mermaid.live URL (real mermaid.js, interactive editor) ----------
// Matches mermaid-live-editor serde: JSON -> zlib deflate(L9) -> url-safe
// base64 (unpadded) -> "pako:" prefix. The diagram rides in the URL fragment,
// which browsers never transmit to the server (stays client-side).
function buildLiveUrl(source, { view = false } = {}) {
  const state = {
    code: source,
    mermaid: JSON.stringify({ theme: 'default' }), // mermaid config is a JSON *string*
    updateDiagram: true,
    rough: false,
    panZoom: true,
  };
  const packed = deflateSync(Buffer.from(JSON.stringify(state), 'utf8'), { level: 9 }).toString('base64url');
  return `https://mermaid.live/${view ? 'view' : 'edit'}#pako:${packed}`;
}

// ---------- main ----------
const opts = parseArgs(process.argv.slice(2));
if (opts.help) { process.stdout.write(HELP + '\n'); process.exit(0); }

const engine = await loadEngine();
const source = readSource(opts);

if (opts.check) validateWithMmdc(source);

if (opts.edit || opts.view) {
  const url = buildLiveUrl(source, { view: opts.view });
  if (opts.url) {
    process.stdout.write(url + '\n');
  } else {
    openInApp(url);
    process.stderr.write(`✓ opened mermaid.live ${opts.view ? 'viewer' : 'editor'} (real mermaid.js)\n  ${url}\n`);
  }
} else if (opts.open || opts.svgOut) {
  const { renderMermaidSVG, THEMES } = engine;
  const colors = THEMES[opts.theme];
  if (!colors) die(`unknown theme: ${opts.theme}\n  themes: ${Object.keys(THEMES).join(', ')}`, 1);
  let svg;
  try { svg = renderMermaidSVG(source, colors); }
  catch (e) { die(`render failed: ${e.message}`, 1); }
  const out = opts.svgOut || join(CACHE_DIR, 'latest.svg');
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, svg);
  if (opts.open) {
    openInApp(out);
    process.stderr.write(`✓ opened ${out}  (theme: ${opts.theme})\n`);
  } else {
    process.stderr.write(`✓ wrote ${out}  (theme: ${opts.theme})\n`);
  }
} else {
  const { renderMermaidASCII } = engine;
  let ascii;
  try { ascii = renderMermaidASCII(source, { useAscii: opts.ascii }); }
  catch (e) { die(`render failed: ${e.message}`, 1); }
  process.stdout.write(ascii.endsWith('\n') ? ascii : ascii + '\n');
}

# WezTerm-on-Windows Performance — Findings

_Date: 2026-07-01 · WezTerm nightly `20260607-082427-8afe0ad3` · RTX 5070 Ti + Intel UHD 770 · RTSS/Afterburner closed_

## TL;DR

- **The complaint is startup, not steady-state.** Interactive paint under bulk output is smooth (~2 ms median, ~3 ms p95). The cost is **opening a window (~1.6 s)**.
- **Startup is dominated by ~880 ms of *diffuse* config-eval**, paid **per gui-process on every window-open** (warm == cold — the persistent mux does not amortize it). No single hotspot.
- **The clean, safe levers are each < 100 ms** (plugins ~16, local requires ~34, tabline.setup ~82, GPU-preference ~76). The bulk (~600 ms) is spread across keybinds, custom tabline components, colors/fonts, `unix_domains`, and event registration — i.e. the features themselves.
- **Applied:** dropped `webgpu_power_preference="HighPerformance"` (see below). Everything else would mean cutting features for < 100 ms each.
- WezTerm's own floor (~725 ms, empty config) is **faster than Windows Terminal** (~917 ms). The gap you feel is our config, and it's mostly irreducible-without-feature-loss.

## Method (what makes these numbers trustworthy)

- **Startup = time to first `paint_impl` log line** (true first frame) from a *freshly-created* gui log. Replaced an earlier `MainWindowHandle`/`Responding` proc-poll that intermittently missed the real window on the full (connect-to-mux) config → spurious 15 s timeouts.
- **Interactive = distribution of `paint_impl elapsed=` values** while a **paced** workload runs *as the pane's initial command* via `-EncodedCommand` (not `wezterm cli send-text`, which mis-routed on the persistent mux and hung; not `-Command`, whose quotes get stripped by `Start-Process` → ParserError).
- **Throughput = wall-clock to render a pre-read 13.3 MB blob** (`[Console]::Out.Write`, disk excluded).
- Cold = `Kill-Wez` per run (deterministic, no orphan accumulation). Median + p95 over N=5, warm-up discarded.
- **Bugs found & fixed in the harness itself** (all in git history): send-text hang, `-Command` quote-stripping (same bug broke `--config front_end="OpenGL"` → moved to config files), flaky startup poll, `$null` LogLines (empty-array-unrolls-to-null), warm-mode orphan accumulation.

## Startup attribution (cold, first-paint, N=5, median)

| Variant | ms | isolates |
|---|---:|---|
| stock `-n` | 714 | no config (WezTerm floor) |
| empty | ~750 | config-file load path |
| plugins-only | ~790 | + 3 `plugin.require` loads → **~16–35 ms** |
| local-requires | ~811 | + 5 local modules → **~34 ms** |
| tabline-setup | ~875 | + `tabline.setup()` → **~82 ms** |
| webgpu-hp | 1253 | WebGpu + HighPerformance **standalone** → +528 ms (RTX cold-init) |
| **full (before)** | **1681** | daily config, WebGpu + HighPerformance |
| **full (after HP drop)** | **1605** | daily config, WebGpu default (iGPU) |

- **config body = full − base ≈ 880 ms.** Cleanly attributable: plugins+requires+tabline ≈ **130 ms**. Remaining **~600 ms is diffuse** (keybinds, `comp` components, colors/fonts, `unix_domains`, event reg).
- **GPU-preference paradox:** HighPerformance costs +528 ms *standalone* but only ~76 ms *inside the full config* — the RTX init runs concurrently with the ~880 ms Lua eval and hides underneath it.
- **Warm ≈ Cold** (warm connect-open ≈ 1.3–2.4 s): mux-spawn is not the cost; config eval per gui-process is.

## Throughput (render a 13.3 MB blob) — the old "10× RTX" is STALE

| front_end | render | startup |
|---|---:|---:|
| OpenGL | ~1.35 s | 846 ms |
| WebGpu iGPU (default) | ~1.40 s | 725 ms |
| WebGpu HighPerformance (RTX) | ~1.6 s | 1253 ms |

The 2026-06-10 note (70.5 s iGPU vs 7.1 s RTX @ 12.3 MB) **does not reproduce** on this nightly — all within ~20 %, with HighPerformance actually *slowest*. HighPerformance was pure loss (slowest startup **and** render).

## Interactive paint (bulk output, N=5) — not a problem

| Variant | median | p95 |
|---|---:|---:|
| stock | 0.4 ms | ~12 ms |
| full | ~1–2 ms | ~3 ms |

## Applied change

`.config/wezterm/wezterm.lua`: removed the Windows `config.webgpu_power_preference = "HighPerformance"` block (commit `76217cb`). Keeps `front_end = "WebGpu"` (TUI-flicker/synchronized-output handling). Net effect: ~76 ms faster cold open, slightly faster bulk render, less GPU power, no throughput loss. **Revert:** re-add `if is_windows then config.webgpu_power_preference = "HighPerformance" end`.

## If you want to push startup lower

The only remaining ~600 ms is diffuse feature-config. Options, in effort order: (1) accept ~1.6 s (using it is smooth); (2) lazy-load modules only used in `update-status`; (3) trim keybind tables / tabline components. Each is a feature/complexity trade for < ~100 ms. Diminishing returns.

## Harness

`./bench.ps1 -Variant <stock|full|opengl|webgpu-hp|empty|plugins-only|tabline-setup|local-requires|no-updatestatus|wt> -Mode <startup|interactive> [-Cold|-Warm] [-Runs N]`. Pure lib unit-tested: `Invoke-Pester bench.Tests.ps1`. Results in `results/` (gitignored).

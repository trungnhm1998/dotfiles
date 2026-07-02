# Local LLM Stack — Design (2026-07-03)

Replace the outdated Ollama setup with a modern local-model stack across three machines, serving coding + agentic tool-use models to Claude Code, opencode, and pi when subscription tokens run out.

## Goals & constraints

- Primary workload: **full agentic coding sessions** (64k+ context, long tool-call loops). Chat is incidental.
- Main PC first, then Mac, then 3090 Ti box.
- Main PC strategy: **swap-on-demand** — fast model default, big model for hard tasks.
- 3090 Ti box stays **Windows**. Mac is dual-role: LAN server when docked, local use when portable.
- All clients run from the main PC (plus the Mac itself when portable).

## Architecture

Three independent endpoints. No cross-machine model splitting (llama.cpp RPC / exo measured strictly worse than single-box + RAM offload). No gateway initially — LiteLLM can be bolted on later if a single hostname + failover becomes worth one more service.

| Box | Endpoint | Stack |
|---|---|---|
| Main PC | `http://127.0.0.1:8080` | llama-swap → llama-server (CUDA, native Windows) |
| 3090 Ti | `http://<3090-ip>:8080` | llama-swap → llama-server, LAN-exposed, Wake-on-LAN |
| MacBook M4 | `http://<mac-ip>:1234` | LM Studio `llmster` headless daemon (MLX engine) |

Every endpoint speaks **both** OpenAI `/v1/chat/completions` and Anthropic `/v1/messages` (llama-server and LM Studio 0.4.1+ implement the Anthropic Messages API natively — no translation proxy needed for Claude Code).

Model swap within a box is llama-swap's job: request a different model name → automatic load/unload, TTL-based idle eviction (frees VRAM for Unity/games).

## Machine 1 — Main PC (RTX 5070 Ti 16GB + 96GB DDR5-5600)

96GB system RAM is the asset: MoE models keep attention + KV cache on GPU and stream experts from RAM (`-ngl 99 --n-cpu-moe N`). Decode speed is RAM-bandwidth-bound — **verify EXPO is enabled in BIOS** before benchmarking (G.Skill Trident Z5 Neo is an AMD EXPO kit — EXPO is AMD's equivalent of XMP; without it the kit runs at JEDEC ~4800 and hybrid decode slows measurably).

**Install** (versions pinned, configs in dotfiles):
- llama.cpp prebuilt Windows CUDA release (Blackwell/sm_120 covered by official CUDA 13 builds). Native Windows — WSL2 gains ~0–5% and adds GPU-passthrough fragility.
- llama-swap (single Go binary) as the front on `:8080`.
- Models on `H:\llm-models\` (~70 GB for both).

**Models:**

| Name | Model | Quant | Placement | Expected |
|---|---|---|---|---|
| `fast` | Qwen3.6-35B-A3B (Apr 2026) | IQ4_XS ~19 GB | mostly GPU, few experts CPU | ~40–60 tok/s |
| `big` | Qwen3-Coder-Next 80B-A3B (Feb 2026, 71.3% SWE-bench Verified, purpose-built for agent scaffolds) | UD-Q4_K_XL ~48 GB (Unsloth GGUF) | attention+KV GPU, experts RAM | ~15–30 tok/s (extrapolated — **must verify**) |
| `tab-qwen2.5-coder-1.5b` | Qwen2.5-Coder-1.5B **base** (FIM-trained; Continue's validated autocomplete pick) | Q8_0 ~2 GB | GPU, **always loaded** | sub-100 ms TTFT target |

**Long context:** `big` runs at **256k context** (`-c 262144`). Qwen3-Coder-Next uses hybrid attention (Gated DeltaNet — only ~¼ of layers keep full KV), so KV at 256k is ~3 GB at q8_0 and stays in VRAM — no speed penalty beyond prompt-processing time. Verify actual KV size in llama-server's load log during P1. `fast` stays at 64k: standard-attention KV at 200k would be ~10 GB (q8_0) and doesn't fit 16 GB alongside weights; `--no-kv-offload` (KV in system RAM) exists as an escape hatch but decodes at ~2–3 tok/s at high fill — not viable for agent loops. Long-context work routes to `big` by design.

**Shared llama-server flags:** `--jinja -fa on -c 65536 --cache-type-k q8_0 --cache-type-v q8_0`
(`--jinja` is mandatory for tool calling; q8_0 KV cache halves KV memory ≈ no quality loss, makes 64k fit.)

**llama-swap config sketch** (`llama-swap.yaml`, exact paths/N tuned during implementation):

```yaml
models:
  "fast":
    cmd: >
      H:\llm\llama.cpp\llama-server.exe
      -m H:\llm-models\Qwen3.6-35B-A3B-IQ4_XS.gguf
      --port ${PORT} -ngl 99 --n-cpu-moe 8
      --jinja -fa on -c 65536 --cache-type-k q8_0 --cache-type-v q8_0
    ttl: 900
  "big":
    cmd: >
      H:\llm\llama.cpp\llama-server.exe
      -m H:\llm-models\Qwen3-Coder-Next-80B-A3B-UD-Q4_K_XL.gguf
      --port ${PORT} -ngl 99 --n-cpu-moe 28
      --jinja -fa on -c 262144 --cache-type-k q8_0 --cache-type-v q8_0
    ttl: 900
  "tab-qwen2.5-coder-1.5b":
    cmd: >
      H:\llm\llama.cpp\llama-server.exe
      -m H:\llm-models\Qwen2.5-Coder-1.5B-Q8_0.gguf
      --port ${PORT} -ngl 99 -c 8192
    # no ttl — always on
```

`tab` lives in its own llama-swap **group** (non-swapping) so it stays resident while `fast`/`big` swap around it — autocomplete must answer in <500 ms at every keystroke and can never wait for a model load. Its ~2 GB VRAM comes out of the chat models' budget: bump their `--n-cpu-moe` a notch to compensate.

`--n-cpu-moe N` is the single tuning knob: raise N until VRAM sits at ~15 GB (leave headroom), lower N for speed. `llama-fit-params` can suggest starting values. If prompt-processing on `big` disappoints, try the Thireus ik_llama.cpp Windows CUDA build as a drop-in — same GGUFs, better hybrid MoE prompt speed. Later optimization (not phase 1): MTP speculative decoding (`--spec-type draft-mtp`) with MTP-variant GGUFs.

## Machine 2 — MacBook M4 24GB

- LM Studio 0.4.x, MLX engine (≈30–50% faster than GGUF/Metal on Apple Silicon), headless via `lms daemon up`, server exposed on LAN `:1234`.
- Model: **Qwen3-Coder-30B-A3B-Instruct, 4-bit MLX** (~17 GB), ~20–30 tok/s on base M4.
- Raise the GPU wired-memory limit (`sudo sysctl iogpu.wired_limit_mb=...`) so a 17 GB model + KV fits comfortably in 24 GB unified.
- **Honest ceiling: 8–16k context.** The Mac is a lite-task endpoint (quick edits, questions, small scripts) — not for full agentic sessions. Docked: pin the model (`ttl` off / keep loaded). Portable: same model used locally.
- Check LM Studio's tool-parser support for the model before downloading alternates (per-model parser coverage varies on MLX).

## Machine 3 — RTX 3090 Ti 24GB (Windows, headless LAN server)

Same stack as the main PC: llama-swap + llama-server, `--host 0.0.0.0`, Windows Firewall inbound rule for 8080 on the **private** profile only. Wake-on-LAN per the existing verified recipe (vault: Wake-on-LAN).

| Name | Model | Quant | Why |
|---|---|---|---|
| `fast27` | Qwen3.6-27B dense | Q4_K_M ~17 GB incl. 32k KV | ~35 tok/s; strongest per-GB coder in 24 GB; spec-decode (DFlash) later can ~2x |
| `devstral` | Devstral Small 2 24B (Dec 2025, 68% SWE-bench Verified) | Q4_K_M | best usable context in 24 GB (~57k), most disciplined agent behavior — the long-session slot |

Role: overflow endpoint — used when the main PC is running `big`, gaming, or Unity owns the VRAM.

## Client wiring (all configs live in dotfiles)

**Claude Code** — per-invocation launcher, **never** `setx`/global env (the subscription path already chains `ANTHROPIC_BASE_URL` through sleev → better-ccflare, and a stale HKCU `ANTHROPIC_BASE_URL` has broken CC before — vault: Diagnosing Claude Code's ECONNREFUSED on Windows). PowerShell function `claude-local` in dotfiles:

```powershell
function claude-local {
    param($Box = "http://127.0.0.1:8080", $Model = "fast")
    $env:ANTHROPIC_BASE_URL = $Box
    $env:ANTHROPIC_AUTH_TOKEN = "none"
    $env:ANTHROPIC_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
    claude @args
}
```

Run it in a dedicated pane so the env doesn't leak into subscription sessions. Additionally set `"CLAUDE_CODE_ATTRIBUTION_HEADER": "0"` in the `env` block of `~/.claude/settings.json` (shell export does not work for this one) — without it CC's per-request attribution hash busts llama-server's prefix cache (up to 90% slower long sessions). Verify during P1 that this setting doesn't disturb subscription sessions; if in doubt, keep it only while using local models. Context floor: CC is unusable below 32k; we serve 64k on `fast`, 256k on `big`.

**opencode** (`~/.config/opencode/opencode.json`) — three provider blocks, `@ai-sdk/openai-compatible`, explicit limits (sketch — full blocks written during implementation; `<3090-ip>`/`<mac-ip>` filled in at P2/P3):

```json
{
  "provider": {
    "local-main": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://127.0.0.1:8080/v1" },
      "models": {
        "fast": { "limit": { "context": 65536, "output": 16384 } },
        "big":  { "limit": { "context": 65536, "output": 16384 } }
      }
    },
    "local-3090": { "…": "same shape, http://<3090-ip>:8080/v1, fast27 + devstral" },
    "local-mac":  { "…": "same shape, http://<mac-ip>:1234/v1, mac30" }
  }
}
```

**pi** (`~/.pi/agent/models.json`) — same three endpoints, `"api": "openai-completions"`, `apiKey: "none"`, `compat: { "supportsDeveloperRole": false }` for local servers.

**Editor autocomplete — Continue (VSCode + Rider) and Zed.** All three editors hit the always-on `tab-qwen2.5-coder-1.5b` on the main PC:

- **Continue** (VSCode extension + JetBrains plugin for Rider): a model entry with `provider: llama.cpp`, `apiBase: http://127.0.0.1:8080`, `roles: [autocomplete]`. Chat/edit roles can point at `fast`/`big` too. **Gotcha:** Continue infers the FIM prompt template from the model *name* — the served ID must keep `qwen2.5-coder` in it (hence the name) or the FIM prefix token goes missing and completions are garbage.
- **Zed**: edit prediction is pluggable (2026) — `edit_predictions` provider `open_ai_compatible` pointed at the same endpoint with `prompt_format: "infer"` (Qwen FIM format inferred from the name). Alternative if quality disappoints: self-host Zed's own open-weight **Zeta2.1** (built for edit-prediction, 136 ms p50) as the tab model instead.

Chat-model IDs stay uniform across boxes (`fast`, `big`, `fast27`, `devstral`, `mac30`) so switching machines = changing base URL only; the tab model is main-PC-only.

## Rollout & verification gates

```
P1 Main PC   install llama-swap + llama.cpp → download `fast`
             → curl /v1/chat/completions with a tool-call request: valid JSON tool call, no template garbage
             → claude-local smoke test: one real agentic task ("add a unit test to X and run it") completes
             → download `big` → verify ≥15 tok/s decode and 256k ctx loads (KV ~3 GB in load log) → tune --n-cpu-moe
             → tab model: Continue in Rider/VSCode completes mid-line in <500 ms with fast/big loaded
P2 Mac       lms daemon + MLX model → curl from main PC over LAN → opencode + claude-local smoke test
P3 3090 Ti   llama-swap + firewall rule + WoL check → both models → smoke test from main PC
```

Gate for every phase: a real agentic task completes end-to-end with working tool calls. Benchmark numbers (tok/s at 0 and ~30k ctx) recorded in the implementation notes for future regression checks.

## Failure modes & ops

- **Too slow / OOM on `big`:** adjust `--n-cpu-moe`, reload llama-swap. No reinstall.
- **Tool calls appear as raw XML/Harmony text:** chat-template problem — update llama.cpp, keep `--jinja`, prefer Unsloth GGUFs (fixed templates).
- **VRAM contention with Unity/games:** llama-swap `ttl` auto-unloads idle models; or hit llama-swap's unload endpoint manually.
- **Mac unreachable:** it's portable by design; fall back to main PC or 3090 Ti endpoints.
- All configs + launcher functions versioned in dotfiles; deploy via existing symlink scripts.

## Explicitly out of scope

- vLLM/SGLang (single-user gain ~7%, minutes-long loads, VRAM pre-allocation) — revisit only if the 3090 Ti serves many concurrent agents.
- Distributed inference across machines (RPC/exo) — measured worse than single-box hybrid.
- LiteLLM gateway — add later if one hostname + failover is wanted; pin versions (March 2026 supply-chain incident).
- Ollama — MoE offload control still missing/buggy; superseded by llama-server router/llama-swap.

## Key sources (mid-2026)

- llama-server Anthropic Messages API: HF blog "Anthropic Messages API in llama.cpp" (Jan 2026); server README.
- MoE CPU offload: HF "llama.cpp MoE offload guide"; `--n-cpu-moe` docs.
- Qwen3-Coder-Next: Qwen blog (Feb 2026), arXiv 2603.00729, Unsloth run guide.
- Qwen3.6 / Devstral Small 2 / model-tier picks: Qwen blog Apr 2026; Mistral Devstral 2 launch (Dec 2025); KDnuggets "Top coding models you can run locally in 2026".
- Claude Code local wiring + attribution-header fix: Unsloth Claude Code guide; LM Studio claudecode blog; community guides (Apr–May 2026).
- Autocomplete: Continue autocomplete model docs (qwen2.5-coder:1.5b validated pick, FIM + latency guidance); Zed edit-prediction provider docs + Zeta2.1 blog (May 2026).
- Caveat: several tok/s figures are extrapolated from adjacent hardware (no direct 5070 Ti + 96 GB benchmarks found) — P1 verification gates exist for this reason. Qwen3.6-27B's 77.2% SWE-bench figure is vendor-adjacent, unverified.

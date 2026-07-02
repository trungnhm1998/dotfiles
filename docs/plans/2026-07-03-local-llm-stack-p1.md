# Local LLM Stack P1 (Main PC) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve three local models (always-on autocomplete + swappable fast/big coding models) on the main PC via llama-swap + llama-server, wired into Claude Code, opencode, pi, Continue (VSCode/Rider), and Zed.

**Architecture:** llama-swap (Go proxy, `127.0.0.1:8080`) fronts llama.cpp `llama-server` instances it spawns on demand. `fast` (Qwen3.6-35B-A3B) and `big` (Qwen3-Coder-Next 80B, experts in system RAM via `--n-cpu-moe`) swap against each other; `tab-qwen2.5-coder-1.5b` stays resident for sub-500ms FIM autocomplete. Clients hit OpenAI `/v1/*` or Anthropic `/v1/messages` on the same port.

**Tech Stack:** llama.cpp prebuilt Windows CUDA release, llama-swap, Hugging Face CLI (`hf`), PowerShell, Windows Task Scheduler.

**Spec:** `docs/specs/2026-07-03-local-llm-stack-design.md` (approved 2026-07-03).

## Global Constraints

- Binaries under `H:\llm\`, models under `H:\llm-models\`. Config + launchers versioned in this dotfiles repo.
- `--jinja` on every chat llama-server instance (tool calling breaks without it).
- KV cache flags on `fast`/`big`: `--cache-type-k q8_0 --cache-type-v q8_0 -fa on`.
- Contexts: `fast` 65536, `big` 262144, `tab` 8192.
- Model IDs are load-bearing: `fast`, `big`, `tab-qwen2.5-coder-1.5b` (Continue infers FIM template from the `qwen2.5-coder` substring — do not rename).
- Pin/record binary versions in `llm/llama-swap.yaml` header comment.
- Git: no `Co-Authored-By` / AI-attribution trailers (user convention).
- Downloads/loads are long: state an ETA and set generous tool timeouts; llama-swap `healthCheckTimeout: 600` because `big` takes minutes to load.
- 2026 model repos are newer than trainer knowledge — every download step first LISTS repo files and picks the matching quant; if a named repo 404s, search HF for the model+quant and record the substitute in the yaml comment.

---

### Task 1: Binaries and directory skeleton

**Files:**
- Create: `H:\llm\llama.cpp\` (extracted release), `H:\llm\llama-swap\`, `H:\llm-models\`
- Create: `llm/llama-swap.yaml` (skeleton, filled in Task 3)

**Interfaces:**
- Produces: `H:\llm\llama.cpp\llama-server.exe` (CUDA-enabled), `H:\llm\llama-swap\llama-swap.exe`, dirs above. Later tasks hard-code these paths.

- [ ] **Step 1: Create directories**

```powershell
New-Item -ItemType Directory -Force H:\llm\llama.cpp, H:\llm\llama-swap, H:\llm-models
```

- [ ] **Step 2: Download latest llama.cpp Windows CUDA release**

Open https://github.com/ggml-org/llama.cpp/releases/latest — pick the `llama-*-bin-win-cuda-x64.zip` asset (CUDA 13.x build; covers Blackwell sm_120). Download + extract:

```powershell
# substitute the actual asset URL from the releases page
Invoke-WebRequest -Uri "<asset-url>" -OutFile H:\llm\llama-cpp.zip
Expand-Archive H:\llm\llama-cpp.zip -DestinationPath H:\llm\llama.cpp -Force
```

- [ ] **Step 3: Verify CUDA device detected**

```powershell
H:\llm\llama.cpp\llama-server.exe --list-devices
```

Expected: output lists the RTX 5070 Ti as a CUDA device. If it lists only CPU, the wrong asset (cpu/vulkan) was downloaded — redo Step 2.

- [ ] **Step 4: Download llama-swap**

From https://github.com/mostlygeek/llama-swap/releases/latest pick the `llama-swap_*_windows_amd64.zip` asset, extract `llama-swap.exe` to `H:\llm\llama-swap\`.

```powershell
Invoke-WebRequest -Uri "<asset-url>" -OutFile H:\llm\llama-swap.zip
Expand-Archive H:\llm\llama-swap.zip -DestinationPath H:\llm\llama-swap -Force
H:\llm\llama-swap\llama-swap.exe --version
```

Expected: a version string prints. Record both versions (llama.cpp build number, llama-swap version) — they go in the yaml header comment in Task 3.

- [ ] **Step 5: Commit skeleton config placeholder**

```powershell
New-Item -ItemType Directory -Force C:\Users\mint\dotfiles\llm
Set-Content C:\Users\mint\dotfiles\llm\llama-swap.yaml "# filled in by Task 3"
git -C C:\Users\mint\dotfiles add llm/llama-swap.yaml
git -C C:\Users\mint\dotfiles commit -m "llm: add llama-swap config placeholder" -- llm/llama-swap.yaml
```

---

### Task 2: Download `tab` and `fast` models

**Files:**
- Create: `H:\llm-models\<tab gguf>`, `H:\llm-models\<fast gguf>`

**Interfaces:**
- Produces: two GGUF paths, recorded for Task 3's yaml. ETA: ~2 GB + ~19 GB — minutes to tens of minutes depending on link; run in background.

- [ ] **Step 1: Install the Hugging Face CLI**

```powershell
pip install -U "huggingface_hub[cli]"
hf version   # falls back: huggingface-cli version
```

- [ ] **Step 2: Download tab model (Qwen2.5-Coder-1.5B base, Q8_0)**

Primary repo `mradermacher/Qwen2.5-Coder-1.5B-GGUF` (base model, matches spec + Continue's recommendation). List first, then fetch the Q8_0 file:

```powershell
hf download mradermacher/Qwen2.5-Coder-1.5B-GGUF --include "*Q8_0*" --local-dir H:\llm-models\
```

Fallback if repo missing: `Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF` q8_0 (instruct variant also carries FIM tokens; note the substitution in the yaml comment).

- [ ] **Step 3: Download fast model (Qwen3.6-35B-A3B, IQ4_XS)**

```powershell
hf download unsloth/Qwen3.6-35B-A3B-GGUF --include "*IQ4_XS*" --local-dir H:\llm-models\
```

If unsloth has no IQ4_XS, take `Q4_K_M`; if the repo name differs, search HF for "Qwen3.6-35B-A3B GGUF" (bartowski/mradermacher mirrors) and record the substitute.

- [ ] **Step 4: Verify files**

```powershell
Get-ChildItem H:\llm-models\ | Select-Object Name, @{n='GB';e={[math]::Round($_.Length/1GB,1)}}
```

Expected: tab ≈ 1.5–2 GB, fast ≈ 18–20 GB. Record exact filenames for Task 3.

---

### Task 3: llama-swap config, autostart, first load

**Files:**
- Modify: `llm/llama-swap.yaml`

**Interfaces:**
- Consumes: binary paths (Task 1), model filenames (Task 2).
- Produces: `http://127.0.0.1:8080` serving OpenAI `/v1/*` + Anthropic `/v1/messages`; model IDs `fast`, `tab-qwen2.5-coder-1.5b` (Task 5 adds `big`). All client tasks depend on this endpoint + these IDs.

- [ ] **Step 1: Write the config**

Substitute the exact filenames from Task 2. Verify `groups` field names against the installed llama-swap's README (semantics required: `tab` always resident; `fast`/`big` mutually exclusive; loading a chat model must NOT evict `tab`):

```yaml
# llama-swap <version> / llama.cpp <build> — pinned <date>
# tab repo: <record actual repo used>
healthCheckTimeout: 600

macros:
  server: 'H:\llm\llama.cpp\llama-server.exe'

models:
  "fast":
    cmd: >
      ${server} -m H:\llm-models\<fast-file>.gguf
      --port ${PORT} -ngl 99 --n-cpu-moe 8
      --jinja -fa on -c 65536 --cache-type-k q8_0 --cache-type-v q8_0
    ttl: 900
  "tab-qwen2.5-coder-1.5b":
    cmd: >
      ${server} -m H:\llm-models\<tab-file>.gguf
      --port ${PORT} -ngl 99 -c 8192

groups:
  chat:
    swap: true
    exclusive: false
    members: ["fast"]        # "big" added in Task 5
  always:
    swap: false
    exclusive: false
    persistent: true
    members: ["tab-qwen2.5-coder-1.5b"]
```

- [ ] **Step 2: Run llama-swap in foreground and smoke it**

```powershell
H:\llm\llama-swap\llama-swap.exe --config C:\Users\mint\dotfiles\llm\llama-swap.yaml --listen 127.0.0.1:8080
```

In a second pane:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/v1/models | ConvertTo-Json -Depth 5
```

Expected: both model IDs listed. Then trigger a load:

```powershell
$body = @{ model = "fast"; messages = @(@{ role="user"; content="Say OK." }); max_tokens = 8 } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri http://127.0.0.1:8080/v1/chat/completions -Method Post -ContentType 'application/json' -Body $body
```

Expected: a completion returns (first call waits through model load). Check `http://127.0.0.1:8080/ui` shows `fast` running. Repeat with `model = "tab-qwen2.5-coder-1.5b"`, then re-request `fast` — **verify tab stays loaded** (both listed as running in the UI). If tab got evicted, the group semantics are wrong — fix per llama-swap README before proceeding.

- [ ] **Step 3: VRAM sanity**

```powershell
nvidia-smi --query-gpu=memory.used --format=csv
```

Expected: ≤ 15.5 GB with both `fast` + `tab` loaded (leave ~0.5 GB headroom). Over budget → raise `--n-cpu-moe` on `fast` by 4 and re-test.

- [ ] **Step 4: Autostart via Task Scheduler (non-elevated)**

```powershell
schtasks /Create /TN "llama-swap" /SC ONLOGON /RL LIMITED /TR "H:\llm\llama-swap\llama-swap.exe --config C:\Users\mint\dotfiles\llm\llama-swap.yaml --listen 127.0.0.1:8080"
schtasks /Run /TN "llama-swap"
Invoke-RestMethod http://127.0.0.1:8080/v1/models
```

Expected: endpoint answers with llama-swap running detached.

- [ ] **Step 5: Commit**

```powershell
git -C C:\Users\mint\dotfiles add llm/llama-swap.yaml
git -C C:\Users\mint\dotfiles commit -m "llm: llama-swap config for fast + tab models" -- llm/llama-swap.yaml
```

---

### Task 4: `fast` — tool-calling and throughput gates

**Files:**
- Modify: `llm/llama-swap.yaml` (only if tuning changes `--n-cpu-moe`)

**Interfaces:**
- Consumes: `fast` on `:8080` (Task 3).
- Produces: verified tool-calling endpoint + recorded tok/s baseline (yaml comment).

- [ ] **Step 1: Tool-call probe**

```powershell
$body = @'
{"model":"fast","max_tokens":128,
 "messages":[{"role":"user","content":"What is the weather in Hanoi? Use the tool."}],
 "tools":[{"type":"function","function":{"name":"get_weather","description":"Get weather for a city","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}]}
'@
Invoke-RestMethod -Uri http://127.0.0.1:8080/v1/chat/completions -Method Post -ContentType 'application/json' -Body $body | ConvertTo-Json -Depth 8
```

Expected: response contains `tool_calls` with `"name": "get_weather"` and valid JSON arguments `{"city":"Hanoi"}` — NOT raw XML/`<tool_call>` text in `content`. Raw-text tool calls = template problem: confirm `--jinja` present and llama.cpp is current; check `Invoke-RestMethod http://127.0.0.1:8080/upstream/fast/props` shows a `chat_template_tool_use` or tool-capable template.

- [ ] **Step 2: Throughput gate**

```powershell
$body = @{ model="fast"; messages=@(@{role="user";content="Write a 300-word explanation of ECS in game engines."}); max_tokens=512 } | ConvertTo-Json -Depth 5
Measure-Command { Invoke-RestMethod -Uri http://127.0.0.1:8080/v1/chat/completions -Method Post -ContentType 'application/json' -Body $body }
```

Read the llama-server log line `eval time = ... tokens per second` (llama-swap UI → logs). Expected: ≥ 40 tok/s decode. Below 40 → lower `--n-cpu-moe` (more experts on GPU) if VRAM allows; verify EXPO/5600 didn't regress (`Get-CimInstance Win32_PhysicalMemory | Select Speed`).

- [ ] **Step 3: Record + commit baseline**

Add a comment line to the yaml: `# fast baseline <date>: N tok/s decode @ --n-cpu-moe <N>, VRAM <X> GB`.

```powershell
git -C C:\Users\mint\dotfiles add llm/llama-swap.yaml
git -C C:\Users\mint\dotfiles commit -m "llm: record fast model baseline" -- llm/llama-swap.yaml
```

---

### Task 5: `big` — download, bring-up, 256k context gate

**Files:**
- Modify: `llm/llama-swap.yaml`

**Interfaces:**
- Consumes: Task 3 endpoint.
- Produces: model ID `big` with 262144 ctx. ETA: ~48 GB download (background it), multi-minute loads.

- [ ] **Step 1: Download (multi-part GGUF)**

```powershell
hf download unsloth/Qwen3-Coder-Next-80B-A3B-GGUF --include "*UD-Q4_K_XL*" --local-dir H:\llm-models\
```

Repo-name fallback per Global Constraints (search "Qwen3-Coder-Next GGUF"). Multi-part files (`-00001-of-0000N.gguf`) all land in the dir; `-m` points at part 00001.

- [ ] **Step 2: Add `big` to the yaml**

```yaml
  "big":
    cmd: >
      ${server} -m H:\llm-models\<big-file>-00001-of-<N>.gguf
      --port ${PORT} -ngl 99 --n-cpu-moe 28
      --jinja -fa on -c 262144 --cache-type-k q8_0 --cache-type-v q8_0
    ttl: 900
```

Add `"big"` to the `chat` group members. Restart llama-swap (`schtasks /End /TN llama-swap; schtasks /Run /TN llama-swap`).

- [ ] **Step 3: Load + KV/VRAM gate**

Request a completion from `big` (same probe as Task 3 Step 2 with `model="big"`). While loading, watch the server log: KV cache allocation should be ~3 GB (hybrid DeltaNet — only ~¼ layers full attention). After load: `nvidia-smi` ≤ 15.5 GB total with `tab` still resident, and `fast` evicted (chat group swap). If KV is ~10+ GB instead, the GGUF isn't the hybrid-attention model — wrong file, stop and re-check the repo.

- [ ] **Step 4: Throughput + tool-call gates**

Same probes as Task 4. Expected: ≥ 15 tok/s decode, clean `tool_calls` JSON. Tune `--n-cpu-moe` (start 28): OOM → +4; VRAM headroom > 1.5 GB → −2 for speed. Record final N + tok/s as a yaml comment. If decode passes but *prompt processing* is painfully slow on long prompts (spec contingency): swap the `${server}` binary for the Thireus ik_llama.cpp Windows CUDA build (https://github.com/Thireus/ik_llama.cpp/releases — same GGUFs, same flags, better hybrid-MoE prefill) for `big` only and re-measure.

- [ ] **Step 5: Long-context spot check**

```powershell
# ~30k-token prompt: paste a large source file into the message
$big = Get-Content C:\Users\mint\dotfiles\claude\* -Raw -ErrorAction SilentlyContinue | Out-String
$body = @{ model="big"; messages=@(@{role="user";content="Summarize in 3 bullets:`n$($big.Substring(0,[Math]::Min(100000,$big.Length)))"}); max_tokens=256 } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri http://127.0.0.1:8080/v1/chat/completions -Method Post -ContentType 'application/json' -Body $body
```

Expected: coherent summary, no OOM, prompt-processing time noted (this is the long-session UX). Commit yaml:

```powershell
git -C C:\Users\mint\dotfiles add llm/llama-swap.yaml
git -C C:\Users\mint\dotfiles commit -m "llm: add big model (Qwen3-Coder-Next 80B, 256k ctx)" -- llm/llama-swap.yaml
```

---

### Task 6: Claude Code wiring

**Files:**
- Create: `powershell/claude-local.ps1`
- Modify: `$PROFILE` (add one dot-source line), `~/.claude/settings.json` (env block)

**Interfaces:**
- Consumes: Anthropic `/v1/messages` on `:8080` (llama-server native).
- Produces: `claude-local [-Box <url>] [-Model <id>]` shell function.

- [ ] **Step 1: Write the launcher**

`powershell/claude-local.ps1`:

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

Add to `$PROFILE`: `. C:\Users\mint\dotfiles\powershell\claude-local.ps1`

Per-invocation env only — never `setx` (protects the sleev→better-ccflare subscription chain; a stale HKCU `ANTHROPIC_BASE_URL` has broken CC before). Run in a dedicated pane; the env persists in that PowerShell session, so don't reuse the pane for subscription `claude`.

- [ ] **Step 2: Attribution-header fix**

In `~/.claude/settings.json`, add to the `env` object (create if absent): `"CLAUDE_CODE_ATTRIBUTION_HEADER": "0"`. Without it CC's per-request hash busts llama-server's prefix cache (up to 90% slower long sessions). Shell export does NOT work for this var.

- [ ] **Step 3: Agentic smoke test**

New pane → `claude-local` → prompt: *"Create scratch file hello.py with a hello() function and a test, run the test, then delete both files."* Expected: CC completes the loop — file writes + bash runs — with no tool-format errors; llama-swap UI shows `/v1/messages` traffic.

- [ ] **Step 4: Subscription-path regression check**

In a **fresh** pane, plain `claude` → verify it still routes through the normal subscription chain (better-ccflare dashboard shows the call) and behaves normally with the attribution env setting present. If subscription behavior degrades, remove the settings.json entry and note it in the spec.

- [ ] **Step 5: Commit**

```powershell
git -C C:\Users\mint\dotfiles add powershell/claude-local.ps1
git -C C:\Users\mint\dotfiles commit -m "llm: claude-local launcher for local model endpoint" -- powershell/claude-local.ps1
```

---

### Task 7: opencode + pi wiring

**Files:**
- Modify: `~/.config/opencode/opencode.json` (create if absent), `~/.pi/agent/models.json` (create if absent)

**Interfaces:**
- Consumes: OpenAI `/v1` on `:8080`, model IDs `fast`/`big`.

- [ ] **Step 1: opencode provider block**

Merge into `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "local-main": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Main PC (llama-swap)",
      "options": { "baseURL": "http://127.0.0.1:8080/v1" },
      "models": {
        "fast": { "name": "Qwen3.6-35B fast (local)", "limit": { "context": 65536, "output": 16384 } },
        "big":  { "name": "Qwen3-Coder-Next 80B (local)", "limit": { "context": 262144, "output": 32768 } }
      }
    }
  }
}
```

- [ ] **Step 2: opencode smoke test**

`opencode` in a scratch dir → `/models` → pick `local-main/fast` → same agentic task as Task 6 Step 3. Expected: tool loop completes; no naked-XML tool calls in output. If thinking tokens leak into responses, set `OPENCODE_DISABLE_CLAUDE_CODE=1` and retest.

- [ ] **Step 3: pi provider block**

Merge into `~/.pi/agent/models.json`:

```json
{
  "providers": {
    "local-main": {
      "baseUrl": "http://127.0.0.1:8080/v1",
      "api": "openai-completions",
      "apiKey": "none",
      "compat": { "supportsDeveloperRole": false, "supportsReasoningEffort": false },
      "models": [
        { "id": "fast", "reasoning": false },
        { "id": "big", "reasoning": false }
      ]
    }
  }
}
```

- [ ] **Step 4: pi smoke test**

`pi` → `/model` → `local-main/fast` → same agentic task. Expected: completes. (models.json hot-reloads — no restart needed.)

- [ ] **Step 5: Commit** — these are per-machine untracked configs; if dotfiles already templates them, update the template and commit, else skip commit and note locations in the yaml comment block.

---

### Task 8: Autocomplete — Continue (VSCode + Rider) and Zed

**Files:**
- Modify: `~/.continue/config.yaml`, Zed `settings.json` (Windows: `%APPDATA%\Zed\settings.json`)

**Interfaces:**
- Consumes: `tab-qwen2.5-coder-1.5b` resident on `:8080`; llama-swap `/upstream/<model>/` passthrough for raw llama.cpp endpoints.

- [ ] **Step 1: Continue autocomplete model**

Add to `~/.continue/config.yaml` `models:` list:

```yaml
  - name: tab-local
    provider: llama.cpp
    model: tab-qwen2.5-coder-1.5b
    apiBase: http://127.0.0.1:8080/upstream/tab-qwen2.5-coder-1.5b
    roles: [autocomplete]
```

(`/upstream/<id>` is llama-swap's raw passthrough to that server's native endpoints — Continue's llama.cpp provider uses `/completion`-style FIM, not `/v1/chat`. Verify the path prefix against the installed llama-swap README.) Continue's JetBrains plugin (Rider) reads the same `~/.continue/config.yaml`.

- [ ] **Step 2: Continue smoke test (VSCode, then Rider)**

Open a C# or Python file → type a half-finished function → expect ghost-text completion < 500 ms. Garbage/no completions → check Continue's output panel: FIM template mis-inference means the model name lost its `qwen2.5-coder` substring, or the apiBase path is wrong.

- [ ] **Step 3: Zed edit prediction**

In Zed `settings.json`:

```json
{
  "edit_predictions": {
    "provider": "open_ai_compatible",
    "api_url": "http://127.0.0.1:8080/v1/completions",
    "model": "tab-qwen2.5-coder-1.5b",
    "prompt_format": "infer",
    "max_output_tokens": 256
  }
}
```

Field names verified against https://zed.dev/docs/ai/edit-prediction at implementation time (provider plumbing is 2026-new). Smoke: same half-finished-function test. If quality disappoints vs Continue, the documented alternative is self-hosting Zeta2.1 as the tab model — note it, don't build it now.

- [ ] **Step 4: Latency-under-load gate**

With `big` loaded (send it a long prompt), immediately trigger autocomplete in the editor. Expected: still < 500 ms — proves `tab` isn't evicted and GPU contention is tolerable. Fails → check group config (Task 3) before blaming the GPU.

---

### Task 9: Capture to wiki + close out

**Files:**
- Create: `C:\ObsidianVaults\05.Wiki\notes\Local LLM Stack.md`
- Modify: `C:\ObsidianVaults\05.Wiki\index.md`, `05.Wiki\log.md`, `05.Wiki\maps\Dev Environment.md`

**Interfaces:**
- Consumes: recorded baselines (Tasks 4/5), final configs.

- [ ] **Step 1: Write the wiki note** — endpoints table, model IDs, measured tok/s, the three load-bearing gotchas (`--jinja`, attribution header, tab-group persistence), link from Dev Environment map. Follow `05.Wiki/CLAUDE.md` ingest rules (re-read vault files before editing; update index + log).

- [ ] **Step 2: Mark P1 done in the spec** — add `Status: P1 implemented <date>, benchmarks: fast N tok/s / big N tok/s` under the spec title; commit:

```powershell
git -C C:\Users\mint\dotfiles add docs/specs/2026-07-03-local-llm-stack-design.md
git -C C:\Users\mint\dotfiles commit -m "llm: record P1 completion + benchmarks in spec" -- docs/specs/2026-07-03-local-llm-stack-design.md
```

P2 (Mac) and P3 (3090 Ti) get their own plans once these numbers exist.

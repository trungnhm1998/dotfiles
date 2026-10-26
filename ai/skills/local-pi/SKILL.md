---
name: local-pi
description: Use to offload small, self-contained tasks to the free local LLM (Qwen3.6 via Pi) instead of spending Claude tokens or spawning a Haiku/Sonnet subagent - e.g. summarizing a file or log, drafting boilerplate, renaming/reformatting, writing a regex, answering a quick factual coding question. Not for multi-file reasoning, architecture, or anything security-sensitive.
---

# local-pi

Delegates a task to Pi running against the local llama-swap server (model `uncensored`, `http://127.0.0.1:8090`).

## Preflight

```bash
curl -sf http://127.0.0.1:8090/health || echo "local LLM down - Max starts it with: ai on"
```

If it is down, tell Max and do the task yourself; do not start it from here (it takes the GPU, and Max keeps it off for gaming).
The first request after `ai on` or after 15 min idle loads the model (up to ~1 min).

## Run

```bash
pi -p --no-session --provider llama-cpp --model uncensored "<self-contained task, include file paths>"
```

- Pi has read/bash/edit/write tools and runs in the current directory. For read-only jobs add `--tools read`.
- Give it everything it needs in the prompt; it shares none of your context.
- Expect 30 s to a few minutes. Set the Bash timeout to 600000.

## After

Treat the output as a junior's draft: check it (diff, run, read) before reporting it as done. If it is wrong twice, do the task yourself.

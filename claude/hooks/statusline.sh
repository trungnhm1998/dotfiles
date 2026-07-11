#!/usr/bin/env bash
# Minimal Claude Code status line: <dir> · <model> · <effort> · <context%>
# Reads session JSON on stdin (see code.claude.com/docs/en/statusline).
# Not a hook, but lives here because claude/hooks/ is per-item symlinked into
# ~/.claude/hooks/ by deploy_windows.ps1 / sync-ai-configs.sh on every platform.
input=$(cat)
IFS=$'\t' read -r cwd model effort pct < <(
  printf '%s' "$input" | jq -r '[
    .workspace.current_dir,
    .model.display_name,
    (.effort.level // "-"),
    (.context_window.used_percentage // 0 | floor)
  ] | @tsv'
)
cwd=${cwd//\\//}          # normalize Windows backslashes to forward slashes
printf '%s · %s · %s · %s%%\n' "${cwd##*/}" "$model" "$effort" "$pct"

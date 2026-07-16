#!/usr/bin/env bash
# Claude Code PostToolUse hook (matcher: EnterWorktree). Seeds a freshly created
# worktree with local-only files from the main worktree. The EnterWorktree
# tool_response schema is undocumented, so try the likely path fields, then fall
# back to the session cwd (Claude has already switched into the new worktree by
# PostToolUse). Never blocks Claude: any failure exits 0.
set -u

input="$(cat)"
path="$(printf '%s' "$input" \
  | jq -r '.tool_response.path // .tool_response.worktreePath // .cwd // empty' 2>/dev/null)"
[ -z "$path" ] && exit 0

script="$HOME/dotfiles/scripts/worktree-seed.sh"
[ -f "$script" ] || exit 0

bash "$script" "$path" >/dev/null 2>&1
exit 0

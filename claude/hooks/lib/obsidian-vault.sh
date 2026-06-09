#!/usr/bin/env bash
# Shared helper — resolve Max's Obsidian vault root, cross-platform.
# Meant to be SOURCED, not executed: `source .../lib/obsidian-vault.sh`.
#
# Why this exists: the vault sits at a different absolute path on each machine
# (~/obsidian-vault/main on macOS, C:\ObsidianVaults on Windows), but the hooks and
# settings are symlinked into ~/.claude on BOTH, so no single hardcoded path works.
# This is the ONE place that knows where the vault might live — add a new machine's
# location to the candidate list and every vault hook picks it up.
#
# Resolution order:
#   1. $OBSIDIAN_VAULT  (explicit per-machine override; export it in your shell rc)
#   2. first existing path in the known-locations list below
# Prints the resolved absolute path and returns 0; prints nothing and returns 1 when
# no vault is found, so callers can: vault="$(resolve_obsidian_vault)" || exit 0

resolve_obsidian_vault() {
  if [ -n "${OBSIDIAN_VAULT:-}" ] && [ -d "$OBSIDIAN_VAULT" ]; then
    printf '%s\n' "$OBSIDIAN_VAULT"
    return 0
  fi

  local candidates=(
    "$HOME/obsidian-vault/main"   # macOS / Linux (this machine)
    "/c/ObsidianVaults"           # Windows, Git-Bash path form
    "C:/ObsidianVaults"           # Windows, drive-letter form
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

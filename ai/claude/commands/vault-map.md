---
description: Manually load the Obsidian vault wiki map (SessionStart auto-hook is disabled)
---

Vault wiki map (manual trigger of the disabled SessionStart hook):

!`bash ~/dotfiles/ai/claude/hooks/vault-map.sh | jq -r '.hookSpecificOutput.additionalContext // empty'`

If the output above is empty, the vault or its index was not found on this machine — say so. Otherwise follow the dispatch instructions it contains.

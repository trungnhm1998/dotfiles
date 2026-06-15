#!/usr/bin/env bash
# One-time: put the Obsidian vault under LOCAL git (no remote) so the close-session
# protocol's auto-captures are committed and revertible. Idempotent.
# Usage: init-vault-git.sh [vault_path]   (defaults to resolved Obsidian vault)
set -euo pipefail

vault="${1:-}"
if [ -z "$vault" ]; then
  source "$HOME/.claude/hooks/lib/obsidian-vault.sh" 2>/dev/null || { echo "vault lib not found"; exit 1; }
  vault="$(resolve_obsidian_vault)" || { echo "no Obsidian vault found"; exit 1; }
fi
[ -d "$vault" ] || { echo "vault path does not exist: $vault"; exit 1; }

cd "$vault"
if [ -d .git ]; then
  echo "vault already a git repo: $vault"
  exit 0
fi

git init -q
cat > .gitignore <<'EOF'
# Obsidian local UI state — not knowledge
.obsidian/workspace*
.obsidian/cache
.trash/
# OS cruft
.DS_Store
Thumbs.db
EOF
git add .gitignore
git commit -q -m "chore: initialise vault git (local audit trail, no remote)"
echo "initialised local git in $vault (no remote)"

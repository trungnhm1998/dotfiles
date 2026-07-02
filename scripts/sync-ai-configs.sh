#!/bin/bash
# Sync authored AI-tool configs (Claude Code + opencode) into place.
# Sourced/called by deploy.sh and setup_mac.sh so both entry points stay in sync.
# Idempotent: safe to re-run.

# Resolve the dotfiles repo root as the parent of this script's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(dirname "$SCRIPT_DIR")"

# Symlink a repo config into place. If the target is a real file/dir, back it up first.
# Uses -n so a directory symlink never gets created *inside* an existing dir.
# Usage: link_config <source-in-repo> <target>
link_config() {
	local src="$1" target="$2"
	if [ -L "$target" ]; then
		ln -sfn "$src" "$target"
		return
	fi
	if [ -e "$target" ]; then
		echo "Backing up existing $target -> ${target}.old"
		mv "$target" "${target}.old"
	fi
	mkdir -p "$(dirname "$target")"
	ln -sfn "$src" "$target"
}

# --- Global agent instructions: one canonical file (claude/AGENTS.md) ---
# Single source of truth shared by Claude Code, Codex, opencode, pi, and Copilot. Claude
# Code reads it as CLAUDE.md; Codex/opencode/pi read it as AGENTS.md; Copilot reads it as
# copilot-instructions.md — each at its own path.
# (Cursor has no global rules file — paste it into User Rules via scripts/copy-agents-rules.sh.)
link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.claude/CLAUDE.md"
link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.claude/AGENTS.md"
link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.codex/AGENTS.md"
link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
link_config "$DOTFILES/claude/AGENTS.md" "$HOME/.copilot/copilot-instructions.md"

# --- Other Claude Code authored config ---
# NOTE: `skills` is deliberately NOT in this whole-dir loop. ~/.claude/skills must stay a
# REAL directory so `npx skills` public installs and Claude Code plugin dirs live beside our
# repo skills. It is linked per-item below. Mirrors deploy_windows.ps1's skills loop.
for item in settings.json agents commands hooks rules themes; do
	link_config "$DOTFILES/claude/$item" "$HOME/.claude/$item"
done

# Claude skills: per-item symlinks into a real ~/.claude/skills (see scripts/lib/link-skills.sh).
source "$SCRIPT_DIR/lib/link-skills.sh"
link_skills "$DOTFILES/claude/skills" "$HOME/.claude/skills"

# opencode: track only opencode.jsonc; remove stale opencode.json (loaded first, would shadow/merge)
rm -f "$HOME/.config/opencode/opencode.json"
link_config "$DOTFILES/.config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"

# Bootstrap the gitignored secrets file from the template if it's missing
if [ ! -f "$HOME/.config/dotfiles/secrets.env" ]; then
	mkdir -p "$HOME/.config/dotfiles"
	cp "$DOTFILES/secrets.env.example" "$HOME/.config/dotfiles/secrets.env"
	chmod 600 "$HOME/.config/dotfiles/secrets.env"
	echo "Created ~/.config/dotfiles/secrets.env — edit it and fill in CONTEXT7_API_KEY."
fi

# Register context7 MCP for Claude Code (idempotent). Key injected at session time via ${CONTEXT7_API_KEY}.
if [ -x "$(command -v claude)" ]; then
	claude mcp remove context7 --scope user 2>/dev/null || true
	claude mcp add --scope user --transport http context7 \
		https://mcp.context7.com/mcp \
		--header 'CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}'
fi

#!/bin/bash
# Starship-inspired status line with Catppuccin Frappe theme

input=$(cat)

# Catppuccin Frappe colors
BLUE='\033[38;2;140;170;238m'      # #8caaee - directory
GREEN='\033[38;2;166;209;137m'     # #a6d189 - git branch
MAUVE='\033[38;2;202;158;230m'     # #ca9ee6 - model
PEACH='\033[38;2;239;159;118m'     # #ef9f76 - context warm
RED='\033[38;2;231;130;132m'       # #e78284 - context hot
YELLOW='\033[38;2;229;200;144m'    # #e5c890 - context mid
TEAL='\033[38;2;129;200;190m'      # #81c8be - context cool
TEXT='\033[38;2;198;208;245m'      # #c6d0f5 - text
RESET='\033[0m'

# Nerd Font icons
FOLDER_ICON="󰉋"
GIT_ICON="󰊢"
MODEL_ICON="󰧑"
CONTEXT_ICON="󰊠"

# Get current directory
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$cwd")

# Get git branch
git_branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_branch=" on ${GREEN}${GIT_ICON} ${branch}${RESET}"
    fi
fi

# Get current model
model=$(echo "$input" | jq -r '.model // "claude"')
case "$model" in
    *opus*) model_display="Opus" ;;
    *sonnet*) model_display="Sonnet" ;;
    *haiku*) model_display="Haiku" ;;
    *) model_display="$model" ;;
esac

# Get context usage
context_used=$(echo "$input" | jq -r '.context.tokensUsed // 0')
context_total=$(echo "$input" | jq -r '.context.contextLimit // 200000')

# Calculate percentage remaining
if [ "$context_total" -gt 0 ] 2>/dev/null; then
    percent_remaining=$(( (context_total - context_used) * 100 / context_total ))
else
    percent_remaining=100
fi

[ "$percent_remaining" -lt 0 ] && percent_remaining=0
[ "$percent_remaining" -gt 100 ] && percent_remaining=100

# Color based on percentage
if [ "$percent_remaining" -ge 75 ]; then
    context_color="$GREEN"
elif [ "$percent_remaining" -ge 50 ]; then
    context_color="$TEAL"
elif [ "$percent_remaining" -ge 25 ]; then
    context_color="$YELLOW"
elif [ "$percent_remaining" -ge 10 ]; then
    context_color="$PEACH"
else
    context_color="$RED"
fi

# Build output
folder_display="${BLUE}${FOLDER_ICON} ${dir_name}${RESET}"
model_display="${MAUVE}${MODEL_ICON} ${model_display}${RESET}"
context_display="${context_color}${CONTEXT_ICON} ${percent_remaining}%${RESET}"

echo -e "${folder_display}${git_branch}  ${model_display}  ${context_display}"

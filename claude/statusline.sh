#!/usr/bin/env bash
# Claude Code Statusline Script
# Displays directory, git branch, model, and context information

# Read JSON from stdin
input_json=$(cat)

# Parse JSON using jq or python
if command -v jq >/dev/null 2>&1; then
    model=$(echo "$input_json" | jq -r '.model.display_name // "Claude"')
    current_dir=$(echo "$input_json" | jq -r '.workspace.current_dir // empty')
    context_percent=$(echo "$input_json" | jq -r '.context_window.used_percentage // 0' | awk '{printf "%.1f", $1}')
    thinking_mode=$(echo "$input_json" | jq -r '.thinking_mode // "none"')
else
    # Fallback to python if jq not available
    read -r model current_dir context_percent thinking_mode < <(python3 -c "
import json, sys, os
data = json.loads('''$input_json''')
model = data.get('model', {}).get('display_name', 'Claude')
current_dir = data.get('workspace', {}).get('current_dir', os.getcwd())
context_percent = round(data.get('context_window', {}).get('used_percentage', 0), 1)
thinking_mode = data.get('thinking_mode', 'none')
print(f'{model} {current_dir} {context_percent} {thinking_mode}')
")
fi

# Get directory basename
dir_name=$(basename "${current_dir:-$(pwd)}")

# Get git branch
git_branch=""
if [ -d "${current_dir:-$(pwd)}/.git" ]; then
    git_branch=$(cd "${current_dir:-$(pwd)}" 2>/dev/null && git branch --show-current 2>/dev/null)
fi

# Catppuccin Frappe RGB colors
text="\033[38;2;198;208;245m"    # #C6D0F5 - main text
sky="\033[38;2;153;209;219m"     # #99D1DB - directory
mauve="\033[38;2;202;158;230m"   # #CA9EE6 - git branch
peach="\033[38;2;239;159;118m"   # #EF9F76 - model name
green="\033[38;2;166;209;137m"   # #A6D189 - context 0-25%
yellow="\033[38;2;229;200;144m"  # #E5C890 - context 25-50%
orange="\033[38;2;239;159;118m"  # #EF9F76 - context 50-75%
red="\033[38;2;231;130;132m"     # #E78284 - context 75-100%
reset="\033[0m"

# Build left section
left_section="${sky}󰉋 ${dir_name}${text}"
if [ -n "$git_branch" ]; then
    left_section+=" on ${mauve}󰊢 ${git_branch}"
fi

# Determine context color based on percentage
context_color="$green"
if (( $(echo "$context_percent > 75" | bc -l) )); then
    context_color="$red"
elif (( $(echo "$context_percent > 50" | bc -l) )); then
    context_color="$orange"
elif (( $(echo "$context_percent > 25" | bc -l) )); then
    context_color="$yellow"
fi

# Format thinking mode with icon
thinking_display=""
if [ "$thinking_mode" != "none" ]; then
    thinking_display=" ${text}󰌵 ${yellow}${thinking_mode}"
fi

# Build right section
right_section="${peach}󰧑 ${model}${thinking_display}${text} | ${context_color}󰾆 ${context_percent}%${reset}"

# Output statusline
echo -e "${left_section}    ${right_section}"

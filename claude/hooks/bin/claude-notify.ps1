param(
    [string]$Title = "Claude Code",
    [string]$Message = "Notification"
)

# Desktop toast only. This script deliberately does NOT focus any WezTerm pane:
# the tab-attention cue is a non-switching bell badge driven by a SetUserVar OSC
# from notify-lib.sh (see .config/wezterm/tabline_claude_badge.lua).
Import-Module BurntToast -ErrorAction SilentlyContinue
New-BurntToastNotification -Text $Title, $Message

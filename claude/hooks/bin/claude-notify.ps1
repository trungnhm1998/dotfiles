#Requires -Version 7.0
param(
    [string]$Title    = "Claude Code",
    [string]$Message  = "Notification",
    [string]$Pane     = "",   # WEZTERM_PANE at fire time (emit mode)
    [string]$Mux      = "",   # mux tag = basename of $WEZTERM_UNIX_SOCKET (emit mode)
    [string]$Activate = ""    # -Activate <uri>: claude-wez:// URI from a toast click (activate mode)
)

# Focus-channel root; CC_FOCUS_DIR is the test seam (parallels the badge's CC_ALERT_DIR).
$focusRoot = if ($env:CC_FOCUS_DIR) { $env:CC_FOCUS_DIR }
             else { Join-Path ($env:XDG_CACHE_HOME ?? (Join-Path $env:USERPROFILE '.cache')) 'claude-notify\wezterm-focus' }

if ($Activate) {
    # --- Activate mode: invoked by the HKCU claude-wez handler on a toast click. ---
    # claude-wez://focus?pane=10&mux=gui-sock-41292  ->  one-shot focus marker file.
    $query = ($Activate -split '\?', 2)[1]
    $kv = @{}
    if ($query) {
        foreach ($pair in ($query -split '&')) {
            $k, $v = $pair -split '=', 2
            if ($k) { $kv[$k] = [uri]::UnescapeDataString([string]$v) }
        }
    }
    $pane = $kv['pane']; $mux = $kv['mux']
    # pane is always a numeric $WEZTERM_PANE; mux is a socket basename (gui-sock-<pid>) or
    # 'default' — neither contains '/', '\', or '.', so this regex rejects path traversal.
    if ($pane -match '^\d+$' -and $mux -match '^[A-Za-z0-9_-]+$') {
        $dir = Join-Path $focusRoot $mux
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() | Set-Content -NoNewline -Path (Join-Path $dir $pane)
    }
    return
}

# --- Emit mode (default): a clickable desktop toast via protocol launch. ---
# pwsh 7 only: BurntToast lives in the pwsh module path; 5.1 cannot see it.
Import-Module BurntToast -ErrorAction SilentlyContinue
$visual = New-BTVisual -BindingGeneric (New-BTBinding -Children (New-BTText -Content $Message))
if ($Pane -and $Mux) {
    $launch  = "claude-wez://focus?pane=$([uri]::EscapeDataString($Pane))&mux=$([uri]::EscapeDataString($Mux))"
    $content = New-BTContent -Visual $visual -Launch $launch -ActivationType Protocol
} else {
    $content = New-BTContent -Visual $visual          # not in WezTerm: plain, non-clickable toast
}
Submit-BTNotification -Content $content

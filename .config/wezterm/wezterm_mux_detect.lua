-- Detects which multiplexer "owns" Ctrl+Space in a pane, so wezterm.lua can hand the prefix to a
-- remote tmux (ssh), WSL's tmux, or a local tmux instead of grabbing WezTerm's own leader.
--
-- The hard part is the persistent `unix` multiplexer domain (mux persistence on Windows): for ANY
-- mux pane, pane:get_foreground_process_name() returns nil -- it is "only available for local
-- panes" (https://wezterm.org/config/lua/pane/get_foreground_process_name.html). That single fact
-- is what silently broke ssh/wsl passthrough once the default domain became the `unix` mux. So we
-- read three signals in priority order:
--   1. user var `mux_prog` -- set by the pwsh ssh/wsl wrappers via OSC 1337 SetUserVar. The ONLY
--      signal that reveals a child process typed *inside* a pwsh pane, since user vars cross the
--      mux (same mechanism as the `zj` zellij flag / CLAUDE_SERVER_PANE in the pwsh profile).
--   2. foreground process name -- authoritative for true local (non-mux) panes, e.g. mac/Linux.
--   3. pane title -- the mux sets it from the pane's ROOT process, so a picker-spawned `ssh mac`
--      pane titles "ssh.exe" even though signal 2 returns nil.
--
-- No require('wezterm'): this loads under plain `lua` for wezterm_mux_detect_test.lua.
local M = {}

-- basename -> strip a trailing .exe -> lowercase. "C:\\OpenSSH\\ssh.exe" -> "ssh", "tmux" -> "tmux".
local function norm(s)
  s = (s:gsub("\\", "/"):match("[^/]+$") or s):lower()
  return (s:gsub("%.exe$", ""))
end

-- Best-known foreground program for a pane, normalized (or "" if nothing is knowable). Every getter
-- is pcall-guarded: a mux pane returns nil for the process name, and any of these can throw.
function M.pane_prog(pane)
  local ok, uv = pcall(function() return pane:get_user_vars() end)
  if ok and uv and uv.mux_prog and uv.mux_prog ~= "" then
    return norm(uv.mux_prog)
  end
  local okf, name = pcall(function() return pane:get_foreground_process_name() end)
  if okf and name and name ~= "" then
    return norm(name)
  end
  local okt, title = pcall(function() return pane:get_title() end)
  if okt and title and title ~= "" then
    return norm(title)
  end
  return ""
end

function M.is_ssh_pane(pane)
  local p = M.pane_prog(pane)
  return p == "ssh" or p == "mosh" or p == "mosh-client"
end

function M.is_tmux_pane(pane)
  return M.pane_prog(pane) == "tmux"
end

-- psmux (native-Windows tmux) owns Ctrl+Space in two cases:
--   1. Launched via the Invoke-Psmux wrapper (tmux/psmux/pmux alias), which sets mux_prog=psmux
--      from the outer pwsh pane before psmux starts -- covers manual launches.
--   2. Auto-spawned (omc-teams / warm pool / teammate) with no wrapper: psmux's set-titles-string
--      prefixes the pane title with "psmux:", and the mux forwards that title to WezTerm even
--      under the persistent unix domain (where fg-process-name is nil and no user var is set).
-- The raw-title check bypasses pane_prog's basename normalization, which would mangle a title
-- containing "/" (e.g. "psmux:file:///...").
function M.is_psmux_pane(pane)
  local p = M.pane_prog(pane)
  if p == "psmux" or p == "pmux" then
    return true
  end
  local ok, title = pcall(function() return pane:get_title() end)
  return ok and title ~= nil and title:find("^psmux:") ~= nil
end

-- WSL "owns" Ctrl+Space when the pane lives in a WSL multiplexer domain (picker-spawned), or when
-- `wsl` was typed inside a pwsh pane (mux_prog user var). The domain check is first and independent
-- of the prog signals -- it is the one that already worked before this fix.
function M.is_wsl_pane(pane)
  local ok, dom = pcall(function() return pane:get_domain_name() end)
  if ok and dom and dom:find("WSL") then
    return true
  end
  return M.pane_prog(pane) == "wsl"
end

return M

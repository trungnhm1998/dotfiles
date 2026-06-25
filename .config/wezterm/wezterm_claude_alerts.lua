-- Pure reconcile logic for the Claude tab-badge alert directory. Extracted from
-- wezterm.lua so it can be unit-tested without loading the full WezTerm config.
-- No `require('wezterm')`: all I/O is injected by the caller.
local M = {}

-- Shared directory contract with claude/hooks/lib/notify-lib.sh.
function M.dir(home, xdg_cache)
  return (xdg_cache or (home .. '/.cache')) .. '/claude-notify/wezterm-alerts'
end

-- paths:    array of absolute file paths (e.g. from wezterm.read_dir)
-- live:     set of currently-live pane-id strings  -> true
-- visited:  set of pane-id strings in the active tab -> true
-- read_file(path) -> string|nil   remove(path) -> ()
-- Returns { [pane_id] = kind }; removes stale (dead pane) and visited files.
function M.reconcile(paths, live, visited, read_file, remove)
  local alerts = {}
  for _, path in ipairs(paths) do
    local id = path:match('([^/\\]+)$')
    if id then
      if not live[id] or visited[id] then
        remove(path)
      else
        local kind = read_file(path)
        if kind then kind = kind:gsub('%s+$', '') end
        if kind and kind ~= '' then alerts[id] = kind end
      end
    end
  end
  return alerts
end

return M

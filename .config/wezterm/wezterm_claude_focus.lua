-- Pure focus-request helpers for the Claude toast-click → focus feature. Extracted
-- from wezterm.lua so it is unit-testable without loading WezTerm. No require('wezterm');
-- all I/O is injected. Sibling of wezterm_claude_alerts.lua (the badge), but a SEPARATE
-- channel (wezterm-focus/, not wezterm-alerts/) with one-shot + TTL semantics.
local M = {}

-- Shared directory contract with claude-notify.ps1 activate-mode.
function M.dir(home, xdg_cache)
  return (xdg_cache or (home .. '/.cache')) .. '/claude-notify/wezterm-focus'
end

-- Per-mux tag = basename of $WEZTERM_UNIX_SOCKET; 'default' when unknown. Identical rule
-- to the badge so a click routes to the exact mux/window that fired.
function M.mux_tag(socket)
  if not socket or socket == '' then return 'default' end
  local tag = socket:match('([^/\\]+)$')
  if not tag or tag == '' then return 'default' end
  return tag
end

function M.mux_dir(home, xdg_cache, socket)
  return M.dir(home, xdg_cache) .. '/' .. M.mux_tag(socket)
end

-- paths: focus-request file paths (e.g. from wezterm.read_dir);  now: os.time();
-- read_file(path)->string|nil   remove(path)->()   ttl: seconds.
-- One-shot: removes EVERY path read; returns the pane ids whose numeric body (epoch
-- seconds) is within ttl of now (drops stale/malformed).
function M.pending(paths, now, read_file, remove, ttl)
  local want = {}
  for _, path in ipairs(paths) do
    local id = path:match('([^/\\]+)$')
    local body = read_file(path)
    remove(path)                                   -- consume regardless
    local ts = body and tonumber(body:match('%d+'))
    if id and ts and (now - ts) <= ttl then
      want[#want + 1] = id
    end
  end
  return want
end

return M

-- yabai.lua — the ONLY module that shells out to the WM.
-- Resolves the binary path once at init (no per-call login shell) for low-latency nudges.
local M = {}

M.CANDIDATES = { "/opt/homebrew/bin/yabai", "/usr/local/bin/yabai" }
M.path = M.CANDIDATES[1]

-- pure: first existing candidate, else the last (injectable existence check for tests)
function M.resolve_path(candidates, exists)
  exists = exists or function(p)
    return hs and hs.fs and hs.fs.attributes(p) ~= nil
  end
  for _, p in ipairs(candidates) do
    if exists(p) then return p end
  end
  return candidates[#candidates]
end

function M.init(exists)
  M.path = M.resolve_path(M.CANDIDATES, exists)
end

-- default executor: hs.execute WITHOUT user-env (path already absolute → no login shell)
local function default_exec(cmd) return hs.execute(cmd) end

function M.run(args, exec)
  exec = exec or default_exec
  return exec(M.path .. " -m " .. args)
end

-- try each until one succeeds (directional focus/move with display fallback on edges)
function M.run_first(list, exec)
  local out, ok
  for _, args in ipairs(list) do
    out, ok = M.run(args, exec)
    if ok then return out, true end
  end
  return out, false
end

-- run all (resize dual-edge: one may no-op depending on window position)
function M.run_all(list, exec)
  for _, args in ipairs(list) do M.run(args, exec) end
end

return M

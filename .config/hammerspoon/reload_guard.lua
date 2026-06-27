-- reload_guard.lua — pure predicate: should a pathwatcher batch trigger hs.reload()?
-- Reload only on a real .lua config change. Ignore busted spec files (they churn during
-- `busted` runs) and the vendored stackline/ tree (40+ files; it manages its own state, and
-- a reload on its changes is pointless + storms during a fork re-sync).
local M = {}

M.IGNORE = { "/spec/", "/stackline/" }

function M.should_reload(files)
  for _, f in ipairs(files) do
    if f:sub(-4) == ".lua" then
      local ignored = false
      for _, frag in ipairs(M.IGNORE) do
        if f:find(frag, 1, true) then ignored = true; break end
      end
      if not ignored then return true end
    end
  end
  return false
end

return M

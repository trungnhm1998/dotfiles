-- Unit test for wezterm_claude_alerts.lua (pure reconcile + dir helpers).
-- arg[1] = absolute path to the module under test.
local module_path = arg[1]
local PASS, FAIL = 0, 0
local function ok(cond, msg)
  if cond then PASS = PASS + 1; print("  PASS: " .. msg)
  else FAIL = FAIL + 1; print("  FAIL: " .. msg) end
end

local M = dofile(module_path)

-- dir(): honours XDG_CACHE_HOME, else home/.cache
ok(M.dir("/home/me", nil) == "/home/me/.cache/claude-notify/wezterm-alerts",
  "dir() defaults to home/.cache")
ok(M.dir("/home/me", "/xdg") == "/xdg/claude-notify/wezterm-alerts",
  "dir() honours XDG_CACHE_HOME")

-- reconcile(): live+unvisited keeps alert; visited removed; dead removed
local removed = {}
local function remove(p) removed[p] = true end
local bodies = { ["/d/10"] = "notification", ["/d/11"] = "stop", ["/d/99"] = "stop" }
local function read_file(p) return bodies[p] end
local paths   = { "/d/10", "/d/11", "/d/99" }
local live    = { ["10"] = true, ["11"] = true }   -- 99 is dead
local visited = { ["11"] = true }                  -- 11 is the active tab
local alerts  = M.reconcile(paths, live, visited, read_file, remove)

ok(alerts["10"] == "notification", "live unvisited pane keeps its alert")
ok(alerts["11"] == nil, "visited pane's alert is dropped")
ok(alerts["99"] == nil, "dead pane's alert is dropped")
ok(removed["/d/11"] == true, "visited pane's file is removed")
ok(removed["/d/99"] == true, "dead pane's file is removed")
ok(removed["/d/10"] == nil, "live unvisited pane's file is kept")

-- reconcile(): trailing whitespace trimmed; empty body -> no entry
local bodies2 = { ["/d/7"] = "notification\n", ["/d/8"] = "" }
local alerts2 = M.reconcile({ "/d/7", "/d/8" }, { ["7"] = true, ["8"] = true }, {},
  function(p) return bodies2[p] end, function() end)
ok(alerts2["7"] == "notification", "trailing newline is trimmed from kind")
ok(alerts2["8"] == nil, "empty body yields no entry")

print(string.format("--- %d passed, %d failed ---", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)

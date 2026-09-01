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

-- mux_tag(): basename of the WezTerm mux socket; handles mixed \ and / separators;
-- 'default' fallback. This is what namespaces alerts per WezTerm process so multiple
-- windows (separate muxes) don't prune each other's files over the shared dir.
ok(M.mux_tag("C:\\Users\\me\\.local/share/wezterm\\gui-sock-41292") == "gui-sock-41292",
  "mux_tag() takes basename across mixed \\ and / separators")
ok(M.mux_tag("/home/me/.local/share/wezterm/gui-sock-7") == "gui-sock-7",
  "mux_tag() takes basename of a pure-/ socket path")
ok(M.mux_tag(nil) == "default", "mux_tag() falls back to 'default' when socket is nil")
ok(M.mux_tag("") == "default", "mux_tag() falls back to 'default' when socket is empty")

-- mux_dir(): per-mux alert subdirectory = dir()/mux_tag(socket)
ok(M.mux_dir("/home/me", nil, "/run/wezterm/gui-sock-3") ==
   "/home/me/.cache/claude-notify/wezterm-alerts/gui-sock-3",
  "mux_dir() namespaces the alert dir by mux tag")
ok(M.mux_dir("/home/me", "/xdg", nil) ==
   "/xdg/claude-notify/wezterm-alerts/default",
  "mux_dir() honours XDG and falls back to 'default' tag")

print(string.format("--- %d passed, %d failed ---", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)

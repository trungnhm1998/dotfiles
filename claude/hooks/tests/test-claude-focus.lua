-- Unit test for wezterm_claude_focus.lua (pure focus-request helpers).
-- arg[1] = absolute path to the module under test.
local module_path = arg[1]
local PASS, FAIL = 0, 0
local function ok(cond, msg)
  if cond then PASS = PASS + 1; print("  PASS: " .. msg)
  else FAIL = FAIL + 1; print("  FAIL: " .. msg) end
end

local M = dofile(module_path)

-- dir(): the wezterm-focus namespace (NOT wezterm-alerts)
ok(M.dir("/home/me", nil) == "/home/me/.cache/claude-notify/wezterm-focus",
  "dir() defaults to home/.cache")
ok(M.dir("/home/me", "/xdg") == "/xdg/claude-notify/wezterm-focus",
  "dir() honours XDG_CACHE_HOME")

-- mux_tag / mux_dir: same basename rule as the badge, focus dir
ok(M.mux_tag("C:\\Users\\me\\wezterm\\gui-sock-41292") == "gui-sock-41292",
  "mux_tag() basename across mixed \\ and /")
ok(M.mux_tag(nil) == "default", "mux_tag() nil -> default")
ok(M.mux_tag("") == "default", "mux_tag() empty -> default")
ok(M.mux_dir("/home/me", nil, "/run/gui-sock-3") ==
   "/home/me/.cache/claude-notify/wezterm-focus/gui-sock-3",
  "mux_dir() namespaces the focus dir by mux tag")

-- pending(): fresh kept + consumed; expired dropped; bad body skipped; all read files removed
local removed = {}
local function remove(p) removed[p] = true end
local bodies = { ["/f/10"]="970", ["/f/11"]="900", ["/f/12"]="oops", ["/f/13"]="1000\n" }
local function read_file(p) return bodies[p] end
local want = M.pending({ "/f/10", "/f/11", "/f/12", "/f/13" }, 1000, read_file, remove, 60)
local set = {}; for _, id in ipairs(want) do set[id] = true end
ok(set["10"] == true, "fresh request within ttl is returned")
ok(set["13"] == true, "fresh request with trailing newline ts is returned")
ok(set["11"] == nil, "expired request (now-ts > ttl) is dropped")
ok(set["12"] == nil, "non-numeric body is skipped")
ok(removed["/f/10"] and removed["/f/11"] and removed["/f/12"] and removed["/f/13"],
  "every read request file is consumed (one-shot)")

ok(#M.pending({}, 1000, read_file, remove, 60) == 0, "empty paths -> no requests")

print(string.format("--- %d passed, %d failed ---", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)

-- Unit test for tabline_claude_badge.lua. Stubs `wezterm`, exercises update().
-- arg[1] = absolute path to the module under test.
local module_path = arg[1]
local PASS, FAIL = 0, 0
local function ok(cond, msg)
  if cond then PASS = PASS + 1; print("  PASS: " .. msg)
  else FAIL = FAIL + 1; print("  FAIL: " .. msg) end
end

local stub = {
  nerdfonts = { md_bell_ring = "RING", md_bell = "BELL" },
  GLOBAL = {},
}
package.loaded.wezterm = stub

local badge = dofile(module_path)

local function tab(is_active, panes) return { is_active = is_active, panes = panes } end
local function pane(id, unseen) return { pane_id = id, has_unseen_output = unseen or false } end

-- 1. precise notification -> ring glyph + peach bg
stub.GLOBAL.claude_alert = { ["5"] = "notification" }
local opts = {}
local r = badge.update(tab(false, { pane(5) }), opts)
ok(r == ' ', "notification renders a badge")
ok(opts.icon and opts.icon[1] == "RING", "notification uses md_bell_ring")
ok(opts.icon.color.bg == "#ef9f76", "notification badge bg is peach")

-- 2. precise stop -> bell glyph + yellow bg
stub.GLOBAL.claude_alert = { ["5"] = "stop" }
opts = {}
badge.update(tab(false, { pane(5) }), opts)
ok(opts.icon[1] == "BELL", "stop uses md_bell")
ok(opts.icon.color.bg == "#e5c890", "stop badge bg is yellow")

-- 3. unseen output but NO claude alert -> no badge (fallback tier removed)
stub.GLOBAL.claude_alert = {}
opts = {}
r = badge.update(tab(false, { pane(9, true) }), opts)
ok(r == nil, "unseen output without an alert renders nothing")
ok(opts.icon == nil, "unseen output sets no icon")

-- 4. no alert at all -> no badge
stub.GLOBAL.claude_alert = {}
opts = {}
r = badge.update(tab(false, { pane(9, false) }), opts)
ok(r == nil, "no alert renders nothing")

-- 5. active tab -> no badge, and the component does NOT mutate GLOBAL
--    (the update-status poller in wezterm.lua owns all clearing now).
stub.GLOBAL.claude_alert = { ["5"] = "notification" }
opts = {}
r = badge.update(tab(true, { pane(5) }), opts)
ok(r == nil, "active tab renders no badge")
ok(stub.GLOBAL.claude_alert["5"] == "notification", "component leaves GLOBAL untouched (poller clears)")

-- 6. alert present and pane also has unseen output -> alert still wins
stub.GLOBAL.claude_alert = { ["5"] = "notification" }
opts = {}
badge.update(tab(false, { pane(5, true) }), opts)
ok(opts.icon[1] == "RING", "alert renders regardless of unseen output")

print(string.format("--- %d passed, %d failed ---", PASS, FAIL))
os.exit(FAIL == 0 and 0 or 1)

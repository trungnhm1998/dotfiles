-- keys.lua — flat Hyper/Meh layer (focus/act + move/relocate). Mirrors komorebi.ahk.
local yabai = require("yabai")
local M = {}

M.HYPER = { "cmd", "alt", "ctrl", "shift" }
M.MEH   = { "alt", "ctrl", "shift" }
M.DIR   = { h = "west", j = "south", k = "north", l = "east" }

-- focus with display fallback on horizontal screen edges
function M.focus(key)
  local d = M.DIR[key]
  if key == "h" or key == "l" then
    return { "window --focus " .. d, "display --focus " .. d }
  end
  return { "window --focus " .. d }
end

-- move = warp, with display fallback on horizontal edges
function M.warp(key)
  local d = M.DIR[key]
  if key == "h" or key == "l" then
    return { "window --warp " .. d, "window --display " .. d .. " --focus" }
  end
  return { "window --warp " .. d }
end

-- helper: bind a Hyper/Meh chord to a single yabai command
local function bind(mods, key, args)
  hs.hotkey.bind(mods, key, function() yabai.run(args) end)
end
local function bind_first(mods, key, list)
  hs.hotkey.bind(mods, key, function() yabai.run_first(list) end)
end

function M.wire()
  -- Hyper: focus / act
  for _, k in ipairs({ "h", "j", "k", "l" }) do bind_first(M.HYPER, k, M.focus(k)) end
  for i = 1, 10 do bind(M.HYPER, tostring(i % 10), "space --focus " .. i) end
  bind_first(M.HYPER, "[", { "window --focus prev", "window --focus last" })
  bind_first(M.HYPER, "]", { "window --focus next", "window --focus first" })
  bind(M.HYPER, ",", "display --focus 1")
  bind(M.HYPER, ".", "display --focus 2")
  bind(M.HYPER, "tab", "space --focus recent")
  hs.hotkey.bind(M.HYPER, "t", function()
    yabai.run("window --toggle float"); yabai.run("window --grid 4:4:1:1:2:2")
  end)
  -- monocle: reuse the relocated helper (it zooms + repaints the border). yabai.sh =
  -- fast non-login /bin/sh with explicit PATH (NOT the interactive login shell, which
  -- blocks HS's main thread). (Task 9 relocates this script.)
  hs.hotkey.bind(M.HYPER, "f", function()
    yabai.sh(os.getenv("HOME") .. "/.config/yabai/scripts/yabai-toggle-zoom.sh")
  end)
  bind(M.HYPER, "x", "space --mirror y-axis")
  bind(M.HYPER, "y", "space --mirror x-axis")
  hs.hotkey.bind(M.HYPER, "c", function() M.cycle_layout(1) end)
  bind(M.HYPER, "q", "window --close")
  bind(M.HYPER, "m", "window --minimize")

  -- Meh: move / relocate
  for _, k in ipairs({ "h", "j", "k", "l" }) do bind_first(M.MEH, k, M.warp(k)) end
  for i = 1, 10 do bind(M.MEH, tostring(i % 10), "window --space " .. i) end
  bind(M.MEH, "p", "window --space prev")
  bind(M.MEH, "n", "window --space next")
  bind(M.MEH, ",", "window --display 1")
  bind(M.MEH, ".", "window --display 2")
  bind(M.MEH, "left",  "window --stack west")
  bind(M.MEH, "down",  "window --stack south")
  bind(M.MEH, "up",    "window --stack north")
  bind(M.MEH, "right", "window --stack east")
  bind_first(M.MEH, "[", { "window --focus stack.prev", "window --focus stack.last" })
  bind_first(M.MEH, "]", { "window --focus stack.next", "window --focus stack.first" })
  hs.hotkey.bind(M.MEH, "c", function() M.cycle_layout(-1) end)
  bind(M.MEH, "return", "window --swap first")  -- promote (best-effort; verify selector live)
end

-- cycle bsp -> stack -> float (dir 1) / reverse (dir -1)
M.LAYOUTS = { "bsp", "stack", "float" }
function M.cycle_layout(dir)
  local out = yabai.run("query --spaces --space")
  local cur = (out or ""):match('"type"%s*:%s*"(%w+)"') or "bsp"
  local idx = 1
  for i, l in ipairs(M.LAYOUTS) do if l == cur then idx = i end end
  local nxt = M.LAYOUTS[((idx - 1 + dir) % #M.LAYOUTS) + 1]
  yabai.run("space --layout " .. nxt)
end

return M

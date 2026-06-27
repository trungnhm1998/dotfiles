-- modes.lua — resize + service modals (hs.hotkey.modal), timer self-heal, OSD hooks.
local M = {}

-- grow deltas per direction — verbatim from the working skhdrc:58-65 dual-edge idiom
local GROW = {
  h = { "left:-50:0",  "right:-50:0" },
  j = { "bottom:0:50", "top:0:50"    },
  k = { "top:0:-50",   "bottom:0:-50"},
  l = { "right:50:0",  "left:50:0"   },
}

local function negate(edge)
  return (edge:gsub("(-?%d+):(-?%d+)", function(a, b)
    return tostring(-tonumber(a)) .. ":" .. tostring(-tonumber(b))
  end))
end

function M.resize_actions(key, grow)
  local base = GROW[key]
  if grow then
    return { "window --resize " .. base[1], "window --resize " .. base[2] }
  end
  return { "window --resize " .. negate(base[1]), "window --resize " .. negate(base[2]) }
end

-- pure: a bsp<->float toggle shell line with the absolute yabai path baked in (PATH-safe)
function M.toggle_layout_cmd(yb)
  return ('L=$(%s -m query --spaces --space | jq -r .type); '
    .. '[ "$L" = float ] && %s -m space --layout bsp || %s -m space --layout float')
    :format(yb, yb, yb)
end

local IDLE = 2.5

-- deps = { yabai = <yabai.lua>, osd = <osd.lua>, hyper = keys.HYPER }
function M.setup(deps)
  local yabai, osd, HYPER = deps.yabai, deps.osd, deps.hyper
  local timer

  local function rearm(modal)
    if timer then timer:stop() end
    timer = hs.timer.doAfter(IDLE, function() modal:exit() end)
  end

  ---------------------------------------------------------------- resize
  M.resize = hs.hotkey.modal.new(HYPER, "r")
  function M.resize:entered() osd.enter("resize"); rearm(self) end
  function M.resize:exited() if timer then timer:stop() end; osd.exit() end
  for _, k in ipairs({ "h", "j", "k", "l" }) do
    M.resize:bind({}, k, function()
      yabai.run_all(M.resize_actions(k, true)); rearm(M.resize)
    end)
    M.resize:bind({ "shift" }, k, function()
      yabai.run_all(M.resize_actions(k, false)); rearm(M.resize)
    end)
  end
  M.resize:bind({}, "escape", function() M.resize:exit() end)
  M.resize:bind({}, "return", function() M.resize:exit() end)

  ---------------------------------------------------------------- service
  M.service = hs.hotkey.modal.new(HYPER, ";")
  function M.service:entered() osd.enter("service"); rearm(self) end
  function M.service:exited() if timer then timer:stop() end; osd.exit() end
  local function act(fn) return function() fn(); M.service:exit() end end
  -- cold-path shell-outs pass user_env=true so `jq` / bare tools resolve under
  -- Hammerspoon's minimal Finder PATH (yabai.run stays on the fast absolute-path route).
  M.service:bind({}, "r", act(function() yabai.run("space --balance") end))
  M.service:bind({}, "p", act(function() hs.execute(M.toggle_layout_cmd(yabai.path), true) end))
  M.service:bind({}, "t", act(function() hs.execute(M.toggle_layout_cmd(yabai.path), true) end))
  M.service:bind({}, "f", act(function() yabai.run("window --toggle native-fullscreen") end))
  M.service:bind({}, "o", act(function() yabai.run("--restart-service"); hs.reload() end))
  M.service:bind({}, "delete", act(function() yabai.run("--restart-service") end))
  M.service:bind({}, "x", act(function()
    hs.execute(os.getenv("HOME") .. "/.config/yabai/scripts/wm-toggle.sh", true)
  end))
  M.service:bind({}, "escape", function() M.service:exit() end)
  M.service:bind({}, "return", function() M.service:exit() end)

  -- panic exit from any state
  hs.hotkey.bind(HYPER, "escape", function() M.exit_all() end)
end

function M.exit_all()
  if M.resize then M.resize:exit() end
  if M.service then M.service:exit() end
end

return M

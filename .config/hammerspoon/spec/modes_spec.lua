local modes = require("modes")

describe("modes.resize_actions", function()
  it("grows with the skhdrc dual-edge deltas", function()
    assert.are.same({ "window --resize right:50:0", "window --resize left:50:0" },
      modes.resize_actions("l", true))
    assert.are.same({ "window --resize left:-50:0", "window --resize right:-50:0" },
      modes.resize_actions("h", true))
  end)
  it("shrinks by negating both deltas", function()
    assert.are.same({ "window --resize right:-50:0", "window --resize left:-50:0" },
      modes.resize_actions("l", false))
    assert.are.same({ "window --resize bottom:0:-50", "window --resize top:0:-50" },
      modes.resize_actions("j", false))
  end)
end)

describe("modes.toggle_layout_cmd", function()
  it("interpolates the resolved yabai path into a bsp<->float toggle", function()
    local cmd = modes.toggle_layout_cmd("/p/yabai")
    assert.is_truthy(cmd:find("/p/yabai %-m query", 1, false))
    assert.is_truthy(cmd:find("space %-%-layout bsp"))
    assert.is_truthy(cmd:find("space %-%-layout float"))
  end)
end)

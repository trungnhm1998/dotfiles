local osd = require("osd")

local function recorder()
  local calls = {}
  return calls, function(cmd) calls[#calls + 1] = cmd end
end

describe("osd.color", function()
  it("uses peach for resize, blue for service", function()
    assert.are.equal("0xffef9f76", osd.color("resize"))
    assert.are.equal("0xff8caaee", osd.color("service"))
  end)
end)

describe("osd.enter", function()
  it("writes the guard flag, sets the border, shows the pill", function()
    local calls, sh = recorder()
    osd.enter("resize", sh)
    local joined = table.concat(calls, "\n")
    assert.is_truthy(joined:find(osd.GUARD, 1, true))          -- flag written
    assert.is_truthy(joined:find("borders active_color=0xffef9f76", 1, true))
    assert.is_truthy(joined:find("sketchybar --set wm_mode drawing=on", 1, true))
  end)
end)

describe("osd.exit", function()
  it("removes the flag, restores the border, hides the pill", function()
    local calls, sh = recorder()
    osd.exit(sh)
    local joined = table.concat(calls, "\n")
    assert.is_truthy(joined:find("rm -f", 1, true))
    assert.is_truthy(joined:find("maximize-border.sh", 1, true))  -- restore correct color
    assert.is_truthy(joined:find("sketchybar --set wm_mode drawing=off", 1, true))
  end)
end)

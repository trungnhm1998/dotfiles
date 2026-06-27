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
  it("writes the guard flag and sets the mode border color", function()
    local calls, sh = recorder()
    osd.enter("resize", sh)
    local joined = table.concat(calls, "\n")
    assert.is_truthy(joined:find(osd.GUARD, 1, true))          -- flag written
    assert.is_truthy(joined:find("borders active_color=0xffef9f76", 1, true))
  end)
end)

describe("osd.exit", function()
  it("removes the flag and restores the border", function()
    local calls, sh = recorder()
    osd.exit(sh)
    local joined = table.concat(calls, "\n")
    assert.is_truthy(joined:find("rm -f", 1, true))
    assert.is_truthy(joined:find("maximize-border.sh", 1, true))  -- restore correct color
  end)
end)

describe("osd HUD", function()
  it("show_hud/hide_hud are safe to call headless (no hs)", function()
    assert.has_no.errors(function() osd.show_hud("resize"); osd.hide_hud() end)
  end)
end)

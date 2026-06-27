local keys = require("keys")

describe("keys.focus", function()
  it("adds a display fallback on horizontal edges", function()
    assert.are.same({ "window --focus west", "display --focus west" }, keys.focus("h"))
    assert.are.same({ "window --focus east", "display --focus east" }, keys.focus("l"))
  end)
  it("has no fallback vertically", function()
    assert.are.same({ "window --focus south" }, keys.focus("j"))
    assert.are.same({ "window --focus north" }, keys.focus("k"))
  end)
end)

describe("keys.warp", function()
  it("warps with a display fallback on horizontal edges", function()
    assert.are.same({ "window --warp west", "window --display west --focus" }, keys.warp("h"))
    assert.are.same({ "window --warp south" }, keys.warp("j"))
  end)
end)

describe("modifier tables", function()
  local function has(t, v)
    for _, x in ipairs(t) do if x == v then return true end end
    return false
  end
  it("Hyper carries cmd, Meh does not", function()
    assert.is_true(has(keys.HYPER, "cmd"))
    assert.is_false(has(keys.MEH, "cmd"))
  end)
end)

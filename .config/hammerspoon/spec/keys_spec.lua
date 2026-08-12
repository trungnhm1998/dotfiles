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

describe("keys.make_double_tap", function()
  it("fires only on two presses within the window", function()
    local fired = 0
    local now = 0
    local press = keys.make_double_tap(0.35, function() fired = fired + 1 end, function() return now end)
    press()            -- t=0: first press, no fire
    assert.are.equal(0, fired)
    now = 0.2
    press()            -- t=0.2: within window -> fire
    assert.are.equal(1, fired)
    now = 0.4
    press()            -- t=0.4: window reset after fire, no fire
    assert.are.equal(1, fired)
    now = 1.0
    press()            -- t=1.0: too slow after t=0.4 press... still no fire
    assert.are.equal(1, fired)
    now = 1.2
    press()            -- t=1.2: within window of t=1.0 -> fire
    assert.are.equal(2, fired)
  end)
end)

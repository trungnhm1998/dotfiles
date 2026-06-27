local reload_guard = require("reload_guard")

describe("reload_guard.should_reload", function()
  it("reloads on a top-level .lua config change", function()
    assert.is_true(reload_guard.should_reload({ "/Users/x/.hammerspoon/keys.lua" }))
  end)

  it("ignores busted spec files", function()
    assert.is_false(reload_guard.should_reload({ "/Users/x/.hammerspoon/spec/keys_spec.lua" }))
  end)

  it("ignores the vendored stackline tree", function()
    assert.is_false(reload_guard.should_reload({ "/Users/x/.hammerspoon/stackline/stackline/window.lua" }))
  end)

  it("ignores non-lua files", function()
    assert.is_false(reload_guard.should_reload({ "/Users/x/.hammerspoon/README.md" }))
  end)

  it("reloads when any file in a mixed batch is a real config change", function()
    assert.is_true(reload_guard.should_reload({
      "/Users/x/.hammerspoon/spec/keys_spec.lua",
      "/Users/x/.hammerspoon/modes.lua",
    }))
  end)
end)

local yabai = require("yabai")

describe("yabai.resolve_path", function()
  it("picks the first candidate that exists", function()
    local exists = function(p) return p == "/usr/local/bin/yabai" end
    assert.are.equal("/usr/local/bin/yabai",
      yabai.resolve_path({ "/opt/homebrew/bin/yabai", "/usr/local/bin/yabai" }, exists))
  end)
  it("falls back to the last candidate when none exist", function()
    local exists = function(_) return false end
    assert.are.equal("/usr/local/bin/yabai",
      yabai.resolve_path({ "/opt/homebrew/bin/yabai", "/usr/local/bin/yabai" }, exists))
  end)
end)

describe("yabai.run", function()
  it("prefixes the resolved path and `-m`", function()
    yabai.path = "/opt/homebrew/bin/yabai"
    local seen
    local exec = function(cmd) seen = cmd; return "", true end
    yabai.run("window --focus west", exec)
    assert.are.equal("/opt/homebrew/bin/yabai -m window --focus west", seen)
  end)
end)

describe("yabai.run_first", function()
  it("stops at the first command that succeeds", function()
    yabai.path = "/p/yabai"
    local calls = {}
    local exec = function(cmd)
      calls[#calls + 1] = cmd
      return "", cmd:find("display") ~= nil  -- only the display fallback succeeds
    end
    local _, ok = yabai.run_first({ "window --focus west", "display --focus west" }, exec)
    assert.is_true(ok)
    assert.are.equal(2, #calls)
  end)
end)

describe("yabai.run_all", function()
  it("runs every command regardless of result", function()
    yabai.path = "/p/yabai"
    local n = 0
    local exec = function(_) n = n + 1; return "", false end
    yabai.run_all({ "window --resize right:50:0", "window --resize left:50:0" }, exec)
    assert.are.equal(2, n)
  end)
end)

-- init.lua — Hammerspoon entry point for the yabai Hyper/Meh scheme.
local yabai = require("yabai")
local keys  = require("keys")
local modes = require("modes")
local osd   = require("osd")

yabai.init()                 -- resolve the binary path once
osd.reset()                  -- clear any stranded mode/border/guard-flag from a prior load
keys.wire()                  -- flat Hyper/Meh layer
modes.setup({ yabai = yabai, osd = osd, hyper = keys.HYPER })

-- auto-reload on a top-level module change under ~/.hammerspoon (config is the repo via
-- symlink). Ignore the spec/ test files: they change during `busted` runs and must NOT
-- reload the live WM — that storm, plus a slow load, was the earlier freeze.
local function reload(files)
  for _, f in ipairs(files) do
    if f:sub(-4) == ".lua" and not f:find("/spec/", 1, true) then hs.reload(); return end
  end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload):start()

hs.alert.show("yabai keybinds loaded")

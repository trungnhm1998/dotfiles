-- init.lua — Hammerspoon entry point for the yabai Hyper/Meh scheme.
local yabai = require("yabai")
local keys  = require("keys")
local modes = require("modes")
local osd   = require("osd")

yabai.init()                 -- resolve the binary path once
osd.reset()                  -- clear any stranded mode/border/guard-flag from a prior load
keys.wire()                  -- flat Hyper/Meh layer
modes.setup({ yabai = yabai, osd = osd, hyper = keys.HYPER })

-- auto-reload on any change under ~/.hammerspoon (config lives in the repo via symlink)
local function reload(files)
  for _, f in ipairs(files) do
    if f:sub(-4) == ".lua" then hs.reload(); return end
  end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload):start()

hs.alert.show("yabai keybinds loaded")

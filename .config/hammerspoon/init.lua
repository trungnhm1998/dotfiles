-- init.lua — Hammerspoon entry point for the yabai Hyper/Meh scheme.
local yabai = require("yabai")
local keys  = require("keys")
local modes = require("modes")
local osd   = require("osd")
local reload_guard = require("reload_guard")

yabai.init()                 -- resolve the binary path once
osd.reset()                  -- clear any stranded mode/border/guard-flag from a prior load
keys.wire()                  -- flat Hyper/Meh layer
modes.setup({ yabai = yabai, osd = osd, hyper = keys.HYPER })

-- stackline: floating per-window stack indicator (pills + app icons). macOS-only.
-- Spec: docs/superpowers/specs/2026-06-28-yabai-stackline-stacking-overlay-design.md
require("hs.ipc")                          -- message port so yabai signals can `hs -c` a refresh
local stackline = require("stackline")     -- vendored fork under ./stackline/ (defines _G.stackline)
stackline:init()                           -- full, valid default config first
for _, kv in ipairs(require("stackline_config")) do
  stackline.config:set(kv[1], kv[2])       -- targeted overrides (init's merge is shallow; :set is per-key safe)
end
stackline.manager:update({ forceRedraw = true })  -- apply overrides visually

-- auto-reload on a top-level module change under ~/.hammerspoon (config is the repo via
-- symlink). Ignore the spec/ test files: they change during `busted` runs and must NOT
-- reload the live WM — that storm, plus a slow load, was the earlier freeze.
local function reload(files)
  if reload_guard.should_reload(files) then hs.reload() end
end
hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reload):start()

hs.alert.show("yabai keybinds loaded")

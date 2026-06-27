-- osd.lua — mode OSD: a centered hs.alert HUD + mode-aware borders color via a guard-flag.
-- The HUD sits in the middle of the focused screen (the old top-bar pill was clipped by the
-- MacBook notch). The guard-flag makes maximize-border.sh early-exit so resize repaints
-- don't fight the mode border color.
local theme = require("theme")
local yabai = require("yabai")
local M = {}

local HOME = os.getenv("HOME") or "~"
M.GUARD = HOME .. "/.cache/yabai/wm-mode"
local BORDER_SCRIPT = HOME .. "/.config/jankyborders/maximize-border.sh"

-- cold path (mode enter/exit only). Routed through yabai.sh = a fast NON-login /bin/sh
-- with an explicit PATH (borders/sketchybar resolve). NOT hs.execute(cmd, true): the
-- interactive login zsh (~0.84s, starts tmux) blocks HS's main thread — the load freeze.
local function default_sh(cmd) return yabai.sh(cmd) end

local LEGEND = {
  resize  = "⟨RESIZE⟩ hjkl nudge · ⇧ shrink · esc",
  service = "⟨SERVICE⟩ r retile · p/t tiling · f full · o reload · ⌫ restart · x wm-off · esc",
}

function M.legend(mode) return LEGEND[mode] or "" end
function M.color(mode) return mode == "resize" and theme.border.resize or theme.border.service end

-- Centered HUD via hs.alert — middle of the focused screen, so the MacBook notch can't clip
-- it. Persists through nudges (long duration); closed on mode exit. Guarded with `hs` so the
-- module still loads headless under busted (where there is no `hs`).
local alertUUID = nil
local HUD_STYLE = {
  fillColor   = { hex = "#303446", alpha = 0.96 },  -- Catppuccin Frappe base
  textColor   = { hex = "#C6D0F5" },                -- Frappe text
  strokeWidth = 3, radius = 14, padding = 18,
  textFont = "JetBrainsMono Nerd Font", textSize = 20,
}

function M.show_hud(mode)
  if not (hs and hs.alert) then return end
  if alertUUID then hs.alert.closeSpecific(alertUUID) end
  local style = {}
  for k, v in pairs(HUD_STYLE) do style[k] = v end
  style.strokeColor = { hex = mode == "resize" and "#EF9F76" or "#8CAAEE" }  -- peach / blue
  alertUUID = hs.alert.show(M.legend(mode), style, hs.screen.mainScreen(), 86400)
end

function M.hide_hud()
  if not (hs and hs.alert) then return end
  if alertUUID then hs.alert.closeSpecific(alertUUID); alertUUID = nil end
end

function M.enter(mode, sh)
  sh = sh or default_sh
  sh(("mkdir -p %q && printf '%%s' %q > %q"):format(HOME .. "/.cache/yabai", mode, M.GUARD))
  sh(("borders active_color=%s"):format(M.color(mode)))
  M.show_hud(mode)
end

function M.exit(sh)
  sh = sh or default_sh
  sh(("rm -f %q"):format(M.GUARD))
  sh(("%q"):format(BORDER_SCRIPT))            -- restore zoom/normal color now the flag is gone
  M.hide_hud()
end

-- idempotent: called on every config (re)load so no phantom mode/border/flag survives
function M.reset(sh) M.exit(sh) end

return M

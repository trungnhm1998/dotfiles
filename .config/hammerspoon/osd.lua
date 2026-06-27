-- osd.lua — mode OSD: sketchybar wm_mode pill + mode-aware borders color via a guard-flag.
-- The guard-flag makes maximize-border.sh early-exit so resize-signal repaints don't fight us.
local theme = require("theme")
local M = {}

local HOME = os.getenv("HOME") or "~"
M.GUARD = HOME .. "/.cache/yabai/wm-mode"
local BORDER_SCRIPT = HOME .. "/.config/jankyborders/maximize-border.sh"

-- cold path (mode enter/exit only — never per-nudge): user_env=true so bare
-- `borders`/`sketchybar` + the border script resolve under Hammerspoon's Finder PATH.
local function default_sh(cmd) return hs.execute(cmd, true) end

local LEGEND = {
  resize  = "⟨RESIZE⟩ hjkl nudge · ⇧ shrink · esc",
  service = "⟨SERVICE⟩ r retile · p/t tiling · f full · o reload · ⌫ restart · x wm-off · esc",
}

function M.legend(mode) return LEGEND[mode] or "" end
function M.color(mode) return mode == "resize" and theme.border.resize or theme.border.service end

function M.enter(mode, sh)
  sh = sh or default_sh
  sh(("mkdir -p %q && printf '%%s' %q > %q"):format(HOME .. "/.cache/yabai", mode, M.GUARD))
  sh(("borders active_color=%s"):format(M.color(mode)))
  sh(("sketchybar --set wm_mode drawing=on label=%q 2>/dev/null"):format(M.legend(mode)))
end

function M.exit(sh)
  sh = sh or default_sh
  sh(("rm -f %q"):format(M.GUARD))
  sh(("%q"):format(BORDER_SCRIPT))            -- restore zoom/normal color now the flag is gone
  sh("sketchybar --set wm_mode drawing=off 2>/dev/null")
end

-- idempotent: called on every config (re)load so no phantom mode/border/flag survives
function M.reset(sh) M.exit(sh) end

return M

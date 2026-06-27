-- theme.lua — Catppuccin Frappe palette + jankyborders color constants (pure data).
local M = {}

M.frappe = {
  base     = "303446",
  red      = "e78284",
  peach    = "ef9f76",
  blue     = "8caaee",
  mauve    = "ca9ee6",
  surface1 = "51576d",
}

local function argb(rgb) return "0xff" .. rgb end

M.border = {
  active   = argb(M.frappe.mauve),    -- normal focused
  inactive = argb(M.frappe.surface1),
  zoom     = argb(M.frappe.red),      -- fullscreen-zoom (owned by maximize-border.sh)
  resize   = argb(M.frappe.peach),    -- resize mode
  service  = argb(M.frappe.blue),     -- service mode
}

return M

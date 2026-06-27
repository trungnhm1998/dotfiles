-- stackline_config.lua — Frappe-parity overrides, applied per-key via stackline.config:set
-- AFTER :init (stackline's :init merge is shallow — u.extend in stackline/stackline.lua:22 — so a
-- partial table to :init would wipe default appearance sub-keys; :set is per-key + schema-validated).
-- #ca9ee6 = Catppuccin Frappe Mauve = jankyborders active border (yabairc:72) =
-- komorebi stackbar_focused_text (Base0E).
return {
  { 'paths.yabai',           '/opt/homebrew/bin/yabai' },                    -- Apple Silicon; this fork already defaults here — pinned for clarity + fork-drift safety
  { 'appearance.showIcons',  true },                                         -- app icons in the pills (the whole point)
  { 'appearance.color',      { red = 0.792, green = 0.620, blue = 0.902 } }, -- focused pill = Frappe Mauve
  { 'appearance.appColors',  {} },                                           -- clear the fork's per-app colors (Chrome/iTerm2/Code) so EVERY app's focus pill is Mauve
  { 'features.clickToFocus', false },                                        -- out of scope; skips the global mouse eventtap
}

local wezterm = require('wezterm')

-- Catppuccin Frappe tokens (kept local so the badge stays on-theme with the rest of
-- the config; change here if the flavour ever changes).
local frappe = {
  crust    = '#232634',
  peach    = '#ef9f76',
  yellow   = '#e5c890',
  overlay0 = '#838ba7',
}

-- Off by default: tmux parity is static, and flashing costs periodic repaints. When
-- true, the urgent "needs you" badge alternates shade once a second (requires a low
-- config.status_update_interval to repaint; see wezterm.lua).
local FLASH = false

return {
  default_opts = {},
  update = function(tab, opts)
    local alerts = wezterm.GLOBAL.claude_alert or {}

    -- Clear-on-visit: visiting the tab dismisses its precise alert. Reassign GLOBAL
    -- (nested writes on the serialization proxy don't persist).
    if tab.is_active then
      local changed = false
      for _, p in ipairs(tab.panes) do
        local k = tostring(p.pane_id)
        if alerts[k] ~= nil then alerts[k] = nil; changed = true end
      end
      if changed then wezterm.GLOBAL.claude_alert = alerts end
      return
    end

    -- Precise tier: any pane in this tab carries a claude_status alert.
    local kind
    for _, p in ipairs(tab.panes) do
      kind = kind or alerts[tostring(p.pane_id)]
    end
    if kind == 'notification' then
      local bg = frappe.peach
      if FLASH and (tonumber(wezterm.time.now():format('%S')) or 0) % 2 == 1 then
        bg = frappe.yellow
      end
      opts.icon = { wezterm.nerdfonts.md_bell_ring, color = { fg = frappe.crust, bg = bg } }
      return ' '
    elseif kind == 'stop' then
      opts.icon = { wezterm.nerdfonts.md_bell, color = { fg = frappe.crust, bg = frappe.yellow } }
      return ' '
    end

    -- Fallback tier: native unseen output, needs no external signal.
    for _, p in ipairs(tab.panes) do
      if p.has_unseen_output then
        opts.icon = { wezterm.nerdfonts.md_bell_outline, color = { fg = frappe.overlay0 } }
        return ' '
      end
    end
  end,
}

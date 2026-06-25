local wezterm = require('wezterm')

-- Catppuccin Frappe tokens (kept local so the badge stays on-theme; change here if the
-- flavour ever changes).
local frappe = {
  crust  = '#232634',
  peach  = '#ef9f76',
  yellow = '#e5c890',
}

return {
  default_opts = {},
  update = function(tab, opts)
    -- Never badge the tab you're on (the update-status poller also clears its alert
    -- on focus). The poller is the sole writer of GLOBAL.claude_alert; this component
    -- only reads it.
    if tab.is_active then return end
    local alerts = wezterm.GLOBAL.claude_alert or {}
    local kind
    for _, p in ipairs(tab.panes) do
      kind = kind or alerts[tostring(p.pane_id)]
    end
    if kind == 'notification' then
      opts.icon = { wezterm.nerdfonts.md_bell_ring, color = { fg = frappe.crust, bg = frappe.peach } }
      return ' '
    elseif kind == 'stop' then
      opts.icon = { wezterm.nerdfonts.md_bell, color = { fg = frappe.crust, bg = frappe.yellow } }
      return ' '
    end
  end,
}

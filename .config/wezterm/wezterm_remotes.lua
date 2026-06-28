-- Pure remote-target builder for the Leader+g picker. No require('wezterm') so it loads under
-- plain `lua` for tests; the picker glue (enumerate_ssh_hosts / InputSelector / SwitchToWorkspace)
-- lives in wezterm.lua where the wezterm runtime exists.
local M = {}

-- ssh_hosts: table<alias, opts> from wezterm.enumerate_ssh_hosts() (wildcards already excluded).
-- wsl_distros: list of { name, is_default } from get_wsl_distros().
-- extras: manual one-offs { label, kind, spawn } (e.g. ssh -t '<host>' 'tmux new -A').
-- Returns ordered targets { label, id, kind, spawn }; id == label (key for the picker map).
function M.build_targets(ssh_hosts, wsl_distros, extras)
  local out = {}
  for _, d in ipairs(wsl_distros or {}) do
    local label = 'wsl:' .. d.name
    out[#out + 1] = { label = label, id = label, kind = 'wsl',
      spawn = { domain = { DomainName = 'WSL:' .. d.name } } }
  end
  local aliases = {}
  for alias in pairs(ssh_hosts or {}) do aliases[#aliases + 1] = alias end
  table.sort(aliases)
  for _, alias in ipairs(aliases) do
    out[#out + 1] = { label = alias, id = alias, kind = 'ssh',
      spawn = { args = { 'ssh', alias } } }
  end
  for _, e in ipairs(extras or {}) do
    out[#out + 1] = { label = e.label, id = e.label, kind = e.kind or 'ssh', spawn = e.spawn }
  end
  return out
end

return M

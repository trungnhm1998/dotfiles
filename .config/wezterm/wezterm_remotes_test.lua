local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
package.path = here .. '/?.lua;' .. package.path
local R = require('wezterm_remotes')

local fails = 0
local function ok(cond, msg) if not cond then fails = fails + 1; print('FAIL ' .. (msg or '')) end end

local ssh = { mac = {}, ['do'] = {}, ['aur.archlinux.org'] = {} }
local wsl = { { name = 'Ubuntu-24.04', is_default = true }, { name = 'Debian' } }
local extras = { { label = 'tunnel', kind = 'vps', spawn = { args = { 'ssh', '-t', 'tunnel', 'tmux new -A -s main' } } } }
local t = R.build_targets(ssh, wsl, extras)

ok(t[1].label == 'wsl:Ubuntu-24.04', 'wsl1 order ' .. tostring(t[1].label))
ok(t[2].label == 'wsl:Debian', 'wsl2 order')
ok(t[3].label == 'aur.archlinux.org', 'ssh sorted 1 ' .. tostring(t[3].label))
ok(t[4].label == 'do', 'ssh sorted 2')
ok(t[5].label == 'mac', 'ssh sorted 3')
ok(t[6].label == 'tunnel', 'extra last')
ok(t[1].spawn.domain.DomainName == 'WSL:Ubuntu-24.04', 'wsl domain spawn')
ok(t[1].kind == 'wsl', 'wsl kind')
ok(t[5].spawn.args[1] == 'ssh' and t[5].spawn.args[2] == 'mac', 'ssh args spawn')
ok(t[5].kind == 'ssh', 'ssh kind')
ok(t[6].spawn.args[3] == 'tunnel', 'extra spawn passthrough')
ok(t[6].id == 'tunnel', 'id == label')
ok(#R.build_targets(nil, nil, nil) == 0, 'all-nil safe')

if fails == 0 then print('wezterm_remotes_test OK') else print(fails .. ' FAILURES'); os.exit(1) end

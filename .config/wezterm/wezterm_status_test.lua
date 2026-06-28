-- Self-locating so it runs from any cwd.
local here = (arg and arg[0] or ''):match('^(.*)[/\\]') or '.'
package.path = here .. '/?.lua;' .. package.path
local M = require('wezterm_status')

local fails = 0
local function eq(got, want, msg)
  if got ~= want then
    fails = fails + 1
    print(('FAIL %s: want %q got %q'):format(msg or '', tostring(want), tostring(got)))
  end
end

-- path_from_url
eq(M.path_from_url('/C:/Users/x', nil), 'C:/Users/x', 'win path C')
eq(M.path_from_url('/D:/repos/y', ''), 'D:/repos/y', 'win path D')
eq(M.path_from_url('/home/max/p', nil), '/home/max/p', 'posix path')
eq(M.path_from_url('/C:/x', 'somehost'), nil, 'remote host nil')
eq(M.path_from_url('//wsl.localhost/Ubuntu/home', nil), nil, 'unc nil')
eq(M.path_from_url(nil, nil), nil, 'nil nil')
eq(M.path_from_url('\\\\server\\share', nil), nil, 'unc backslash nil')

-- host_of
local h = M.host_of('WSL:Ubuntu-24.04', 'bash', { wsl_icon = 'W' })
eq(h.kind, 'wsl', 'wsl kind'); eq(h.label, 'Ubuntu-24.04', 'wsl label'); eq(h.icon, 'W', 'wsl icon')
h = M.host_of('local', 'C:/Windows/System32/OpenSSH/ssh.exe',
  { ssh_icon = 'S', workspace = 'mac', icon_overrides = { mac = 'A' } })
eq(h.kind, 'ssh', 'ssh kind'); eq(h.label, 'mac', 'ssh label'); eq(h.icon, 'A', 'ssh override icon')
h = M.host_of('local', 'ssh', { ssh_icon = 'S', workspace = 'vps' })
eq(h.kind, 'ssh', 'ssh basename'); eq(h.label, 'vps', 'ssh ws label'); eq(h.icon, 'S', 'ssh default icon')
h = M.host_of('local', 'pwsh.exe', { local_icon = 'L' })
eq(h.kind, 'local', 'local kind'); eq(h.icon, 'L', 'local icon')

-- git_status
local cache = {}
local gs = M.git_status(function() return true, '## main...origin/main\n M file.lua\n', '' end, 100, 'C:/repo', cache, 3)
eq(gs.branch, 'main', 'branch parse'); eq(gs.dirty, true, 'dirty true')
local gs2 = M.git_status(function() error('must not run on cache hit') end, 101, 'C:/repo', cache, 3)
eq(gs2.branch, 'main', 'cache hit')
local gs3 = M.git_status(function() return true, '## dev\n', '' end, 200, 'C:/repo2', cache, 3)
eq(gs3.branch, 'dev', 'clean branch'); eq(gs3.dirty, false, 'dirty false')
eq(M.git_status(function() return false, '', 'fatal' end, 300, 'C:/x', cache, 3), nil, 'non-repo nil')
eq((M.git_status(function() return true, '## release/2.1...origin/release/2.1\n', '' end, 500, 'C:/repo3', cache, 3)).branch, 'release/2.1', 'dotted branch full')
eq(M.git_status(function() error('must not run') end, 400, nil, cache, 3), nil, 'nil path nil')

-- git_toplevel
local tcache = {}
eq(M.git_toplevel(function() return true, 'C:/Users/max/dotfiles\n', '' end, 100, 'C:/Users/max/dotfiles/.config', tcache, 30),
   'dotfiles', 'repo name')

-- adapters: object (method) vs info (field)
local obj = { get_domain_name = function() return 'WSL:Debian' end,
              get_foreground_process_name = function() return '/usr/bin/nvim' end,
              get_current_working_dir = function() return { file_path = '/home/x' } end }
eq(M.adapt_domain(obj), 'WSL:Debian', 'adapt_domain method')
eq(M.adapt_fg(obj), '/usr/bin/nvim', 'adapt_fg method')
eq(M.adapt_cwd(obj).file_path, '/home/x', 'adapt_cwd method')
local info = { domain_name = 'local', foreground_process_name = 'pwsh.exe',
               current_working_dir = { file_path = '/C:/r' } }
eq(M.adapt_domain(info), 'local', 'adapt_domain field')
eq(M.adapt_fg(info), 'pwsh.exe', 'adapt_fg field')
eq(M.adapt_cwd(info).file_path, '/C:/r', 'adapt_cwd field')

-- proc_label: basename (handles backslash) + strip .exe + icon-map lookup
local imap = { pwsh = 'P', nvim = 'V', default = 'D' }
local pl = M.proc_label('C:\\Program Files\\PowerShell\\7\\pwsh.exe', imap)
eq(pl.name, 'pwsh', 'proc win path basename + de-exe'); eq(pl.icon, 'P', 'proc pwsh icon')
pl = M.proc_label('/usr/bin/nvim', imap)
eq(pl.name, 'nvim', 'proc posix basename'); eq(pl.icon, 'V', 'proc nvim icon')
pl = M.proc_label('node', imap)
eq(pl.name, 'node', 'proc bare name'); eq(pl.icon, 'D', 'proc unknown -> default icon')
eq(M.proc_label('', imap), nil, 'proc empty -> nil')
eq(M.proc_label(nil, imap), nil, 'proc nil -> nil')

if fails == 0 then print('wezterm_status_test OK') else print(fails .. ' FAILURES'); os.exit(1) end

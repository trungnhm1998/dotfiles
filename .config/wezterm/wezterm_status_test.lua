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

-- Real PaneInformation (tab data) is STRICT: indexing a Pane *method* name on it raises, unlike
-- the permissive plain-table stubs above. read() must probe the method under pcall and fall
-- through to the data field, or every tab component throws and silently blanks (only the tab
-- index renders). Regression for that exact GUI bug.
do
  local strict = setmetatable(
    { domain_name = 'WSL:Ubuntu', foreground_process_name = 'C:\\x\\pwsh.exe',
      current_working_dir = { file_path = '/C:/r' } },
    { __index = function(_, k) error('strict PaneInformation: no field ' .. tostring(k)) end })
  eq(M.adapt_domain(strict), 'WSL:Ubuntu', 'adapt_domain strict-info via field')
  eq(M.adapt_fg(strict), 'C:\\x\\pwsh.exe', 'adapt_fg strict-info via field')
  eq(M.adapt_cwd(strict).file_path, '/C:/r', 'adapt_cwd strict-info via field')
end

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

-- proc_display: prefer fg; fall back to title (mux panes report no fg); reject descriptive titles.
eq(M.proc_display('C:\\x\\pwsh.exe', nil, imap).name, 'pwsh', 'proc_display uses fg')
eq(M.proc_display('', 'C:\\Program Files\\PowerShell\\7\\pwsh.exe', imap).name, 'pwsh',
   'proc_display falls back to title when fg empty (mux pane)')
eq(M.proc_display(nil, 'dotfiles - Lazygit', imap), nil, 'proc_display rejects spaced/descriptive title')
eq(M.proc_display(nil, '⠐ Verify and research', imap), nil, 'proc_display rejects Claude activity title')
eq(M.proc_display('', '', imap), nil, 'proc_display empty -> nil')

-- Window components must resolve the active pane from `window` alone (tabline may pass 1 arg).
do
  local stub_pane = {
    get_domain_name = function() return 'local' end,
    get_foreground_process_name = function() return 'C:/x/pwsh.exe' end,
    get_current_working_dir = function() return { file_path = '/C:/repo', host = nil } end,
  }
  local stub_window = {
    active_pane = function() return stub_pane end,
    active_workspace = function() return 'main' end,
    mux_window = function() return { tabs = function() return { 1, 2 } end } end,
  }
  local nf = setmetatable({}, { __index = function() return 'I' end })
  local stub_wez = {
    nerdfonts = nf,
    run_child_process = function() return true, '## main\n', '' end,
    mux = { get_workspace_names = function() return { 'main', 'other' } end },
  }
  local comp = M.components(stub_wez, { local_icon = 'L', ssh_icon = 'S', wsl_icon = 'W' })
  eq(comp.host_badge(stub_window), ' L local ', 'host_badge resolves pane from window only (padded)')
  eq(comp.focused_process(stub_window), 'pwsh', 'focused_process from window only')
  assert(comp.counts(stub_window):find('2 ws'), 'counts from window only')
  assert(comp.git_branch(stub_window):find('main'), 'git_branch resolves pane from window only')
  -- Windows drops the local glyph (nil local_icon): label only, no leading icon / double space.
  local comp2 = M.components(stub_wez, { ssh_icon = 'S', wsl_icon = 'W' })
  eq(comp2.host_badge(stub_window), ' local ', 'host_badge nil icon -> label only')
end

-- Tab components: tabline calls them with a TabInformation (1 arg) whose active_pane is a STRICT
-- PaneInformation. They must resolve via tab.active_pane, read fields through the pcall-guarded
-- adapter, and self-separate with a leading space. Regression for "tab only shows the index".
do
  local strict_pane = setmetatable(
    { domain_name = 'local', foreground_process_name = 'C:\\Program Files\\PowerShell\\7\\pwsh.exe',
      current_working_dir = { file_path = '/C:/Users/max/dotfiles', host = nil } },
    { __index = function(_, k) error('strict PaneInformation: no field ' .. tostring(k)) end })
  local tab = { tab_index = 0, active_pane = strict_pane, panes = { 1, 2 } }
  local nf = setmetatable({}, { __index = function() return 'I' end })
  local stub_wez = {
    nerdfonts = nf,
    run_child_process = function() return false, '', '' end, -- not a git repo -> basename fallback
    mux = { get_workspace_names = function() return {} end },
  }
  local comp = M.components(stub_wez, { local_icon = 'L', ssh_icon = 'S', wsl_icon = 'W', pane_glyph = '#' })
  eq(comp.process(tab), ' I pwsh', 'tab process: icon + de-exe basename, space-led')
  eq(comp.tab_host_icon(tab), ' L', 'tab host icon: local glyph, space-led')
  eq(comp.smart_dir(tab), ' dotfiles', 'tab smart_dir: leaf/repo basename, space-led')
  eq(comp.pane_count(tab), ' #2', 'tab pane_count: glyph+count, space-led')
end

-- Tab process falls back to the LIVE MuxPane when the snapshot fg is empty (mux-domain panes),
-- so nvim/lazygit/node resolve in tabs -- not just plain pwsh. Regression for that exact report.
do
  local strict_pane = setmetatable(
    { domain_name = 'unix', foreground_process_name = '', current_working_dir = { file_path = '/C:/r' } },
    { __index = function(_, k) error('strict PaneInformation: no field ' .. tostring(k)) end })
  rawset(strict_pane, 'pane_id', 7) -- present key, so strict __index won't fire on access
  local tab = { tab_index = 0, active_pane = strict_pane, panes = { 1 } }
  local nf = setmetatable({}, { __index = function() return 'I' end })
  local stub_wez = {
    nerdfonts = nf,
    run_child_process = function() return false, '', '' end,
    mux = {
      get_workspace_names = function() return {} end,
      get_pane = function(_) return { get_foreground_process_name = function() return 'C:\\bin\\nvim.exe' end } end,
    },
  }
  local comp = M.components(stub_wez, { local_icon = 'L' })
  eq(comp.process(tab), ' I nvim', 'tab process: live MuxPane fallback when snapshot fg is empty')
end

if fails == 0 then print('wezterm_status_test OK') else print(fails .. ' FAILURES'); os.exit(1) end

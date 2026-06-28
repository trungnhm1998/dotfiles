-- Pure host/git/url helpers + object-or-info adapters for the WezTerm status bar & tabs.
-- No require('wezterm') at top level: all GUI deps are injected (run_child_process) or passed
-- to components() so this module loads under plain `lua` for unit tests. Sibling of
-- wezterm_claude_focus.lua (same injected-I/O, testable-pure style).
local M = {}

-- Url.file_path -> a path `git -C` accepts, or nil for remote/UNC/WSL paths.
-- Windows file_path looks like "/C:/Users/x"; host is set when cwd came from a remote OSC 7.
function M.path_from_url(file_path, host)
  if host and host ~= '' and host ~= 'localhost' then return nil end
  if not file_path or file_path == '' then return nil end
  if file_path:match('^//') or file_path:match('^\\\\') then return nil end -- UNC / \\wsl$
  local win = file_path:match('^/(%a:/.*)$')                                -- /C:/x -> C:/x
  if win then return win end
  return file_path                                                          -- posix self
end

local function basename(s)
  if not s or s == '' then return '' end
  return (s:gsub('\\', '/'):gsub('/+$', ''):match('[^/]+$')) or s
end

-- Classify a pane's host from its domain name + foreground process name (both strings).
function M.host_of(domain_name, fg_process_name, opts)
  opts = opts or {}
  local dn = domain_name or ''
  if dn:find('WSL') then
    return { kind = 'wsl', icon = opts.wsl_icon, label = (dn:gsub('^WSL:%s*', '')) }
  end
  local proc = basename(fg_process_name):lower()
  if proc == 'ssh' or proc == 'ssh.exe' or proc == 'mosh' or proc == 'mosh.exe'
     or proc == 'mosh-client' or proc == 'mosh-client.exe' then
    local ws = opts.workspace or ''
    local icon = (opts.icon_overrides or {})[ws] or opts.ssh_icon
    return { kind = 'ssh', icon = icon, label = (ws ~= '' and ws or 'ssh') }
  end
  return { kind = 'local', icon = opts.local_icon, label = 'local' }
end

-- git branch + dirty in one call: `git -C <path> status --porcelain --branch`.
-- run(args) -> success, stdout, stderr (matches wezterm.run_child_process). Cached by path.
function M.git_status(run, now, path, cache, ttl)
  if not path then return nil end
  ttl = ttl or 3
  local hit = cache[path]
  if hit and (now - hit.ts) < ttl then return hit.val end
  local pok, ok, stdout = pcall(run, { 'git', '-C', path, 'status', '--porcelain', '--branch' })
  local val = nil
  if pok and ok and stdout then
    local first = stdout:match('^[^\r\n]*') or ''
    local branch = first:match('^## ([^\r\n]+)')
    if branch then
      branch = (branch:gsub('%.%.%..*$', ''):gsub('%s+$', ''))
      local body = stdout:gsub('^[^\r\n]*\r?\n?', '')
      val = { branch = branch, dirty = body:match('%S') ~= nil }
    end
  end
  cache[path] = { ts = now, val = val }
  return val
end

-- Repo name (basename of toplevel) or nil. Cached by path with a longer TTL.
function M.git_toplevel(run, now, path, cache, ttl)
  if not path then return nil end
  ttl = ttl or 30
  local hit = cache[path]
  if hit and (now - hit.ts) < ttl then return hit.val end
  local pok, ok, stdout = pcall(run, { 'git', '-C', path, 'rev-parse', '--show-toplevel' })
  local val = nil
  if pok and ok and stdout then
    local top = stdout:match('^[^\r\n]+')
    if top then val = basename(top) end
  end
  cache[path] = { ts = now, val = val }
  return val
end

-- tabline passes Window/Pane OBJECTS to window-section fns and TabInformation/PaneInformation
-- (data) to tab fns. These adapters read either shape so the same logic serves both.
local function read(pane, method, field)
  if not pane then return nil end
  local m = pane[method]
  if type(m) == 'function' then
    local ok, v = pcall(m, pane)
    if ok then return v end
  end
  return pane[field]
end
function M.adapt_domain(pane) return read(pane, 'get_domain_name', 'domain_name') end
function M.adapt_fg(pane) return read(pane, 'get_foreground_process_name', 'foreground_process_name') end
function M.adapt_cwd(pane) return read(pane, 'get_current_working_dir', 'current_working_dir') end

-- Pure: derive { name, icon } from a foreground process path. name = basename minus a trailing
-- .exe; icon = icon_map[name:lower()] or icon_map.default. Returns nil for empty/nil input.
function M.proc_label(fg_process_name, icon_map)
  local base = basename(fg_process_name)
  if base == '' then return nil end
  local name = base:gsub('%.[Ee][Xx][Ee]$', '')
  local icon = nil
  if icon_map then icon = icon_map[name:lower()] or icon_map.default end
  return { name = name, icon = icon }
end

M.basename = basename

-- Build tabline.wez inline component functions. `wezterm` is passed in (not required) so the
-- pure cores above stay loadable under plain lua. Every fn is pcall-wrapped -> '' on error,
-- so a single throw can never freeze the tab bar (a known WezTerm failure mode).
function M.components(wezterm, opts)
  opts = opts or {}
  local nf = wezterm.nerdfonts
  local run = wezterm.run_child_process
  local branch_cache, top_cache = {}, {}
  local dirty_mark = opts.dirty_mark or '●'
  local pane_glyph = opts.pane_glyph or nf.cod_split_horizontal or '|'
  local proc_icons = opts.proc_icons or {
    pwsh = nf.cod_terminal_powershell, powershell = nf.cod_terminal_powershell,
    cmd = nf.md_console, bash = nf.cod_terminal_bash, zsh = nf.cod_terminal,
    fish = nf.md_fish, nvim = nf.custom_neovim, vim = nf.custom_vim,
    node = nf.md_nodejs, python = nf.md_language_python, python3 = nf.md_language_python,
    git = nf.dev_git, lazygit = nf.cod_github, cargo = nf.dev_rust, go = nf.seti_go,
    lua = nf.seti_lua, docker = nf.md_docker, ssh = nf.md_ssh, claude = nf.md_robot_outline,
    default = nf.cod_terminal,
  }
  local C = {}

  local function safe(fn)
    return function(a, b)
      local ok, res = pcall(fn, a, b)
      return (ok and res) or ''
    end
  end
  local function is_remote(pane)
    local dn = M.adapt_domain(pane) or ''
    if dn:find('WSL') then return true end
    local p = M.basename(M.adapt_fg(pane)):lower()
    return p:find('^ssh') ~= nil or p:find('^mosh') ~= nil
  end

  -- WINDOW components (real Window/Pane objects) -------------------------------
  C.git_branch = safe(function(window, pane)
    pane = pane or (window and window:active_pane())
    if not pane or is_remote(pane) then return '' end
    local cwd = M.adapt_cwd(pane)
    if not cwd then return '' end
    local path = M.path_from_url(cwd.file_path, cwd.host)
    local gs = M.git_status(run, os.time(), path, branch_cache, opts.git_ttl or 3)
    if not gs then return '' end
    return nf.dev_git .. ' ' .. gs.branch .. (gs.dirty and (' ' .. dirty_mark) or '')
  end)

  C.host_badge = safe(function(window, pane)
    pane = pane or (window and window:active_pane())
    if not pane then return '' end
    local ws = nil
    pcall(function() ws = window:active_workspace() end)
    local h = M.host_of(M.adapt_domain(pane), M.adapt_fg(pane), {
      local_icon = opts.local_icon, wsl_icon = opts.wsl_icon, ssh_icon = opts.ssh_icon,
      workspace = ws, icon_overrides = opts.icon_overrides,
    })
    return (h.icon or '') .. ' ' .. (h.label or '')
  end)

  C.focused_process = safe(function(window, pane)
    pane = pane or (window and window:active_pane())
    if not pane then return '' end
    return (M.basename(M.adapt_fg(pane)):gsub('%.exe$', ''))
  end)

  C.counts = safe(function(window, pane)
    local ws = #wezterm.mux.get_workspace_names()
    local tabs = 0
    pcall(function() tabs = #window:mux_window():tabs() end)
    return string.format('%d ws · %d tabs', ws, tabs)
  end)

  -- TAB components (TabInformation / PaneInformation data) ---------------------
  C.process = safe(function(tab, pane)
    local pi = pane or (tab and tab.active_pane)
    if not pi then return '' end
    local pl = M.proc_label(M.adapt_fg(pi), proc_icons)
    if not pl then return '' end
    return (pl.icon and (pl.icon .. ' ') or '') .. pl.name
  end)

  C.tab_host_icon = safe(function(tab, pane)
    local pi = pane or (tab and tab.active_pane)
    if not pi then return '' end
    local h = M.host_of(M.adapt_domain(pi), M.adapt_fg(pi), {
      local_icon = opts.local_icon, wsl_icon = opts.wsl_icon, ssh_icon = opts.ssh_icon,
    })
    return h.icon or ''
  end)

  C.smart_dir = safe(function(tab, pane)
    local pi = pane or (tab and tab.active_pane)
    if not pi then return '' end
    local cwd = M.adapt_cwd(pi)
    if not cwd then return '' end
    local path = M.path_from_url(cwd.file_path, cwd.host)
    if not path then
      if cwd.host and cwd.host ~= '' then return cwd.host end
      return M.basename(cwd.file_path)
    end
    if is_remote(pi) then return M.basename(path) end
    local repo = M.git_toplevel(run, os.time(), path, top_cache, opts.top_ttl or 30)
    return repo or M.basename(path)
  end)

  C.pane_count = safe(function(tab, pane)
    if not tab or not tab.panes then return '' end
    local n = #tab.panes
    if n <= 1 then return '' end
    return pane_glyph .. n
  end)

  return C
end

return M

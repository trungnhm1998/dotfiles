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
  -- A real Pane object exposes `method` as a function. A PaneInformation (tab data) has no such
  -- key AND is strict -- indexing an unknown key RAISES -- so probe the method under pcall, then
  -- fall through to the data `field`. Without the pcall, every tab component throws here and
  -- silently blanks (only the tab index renders).
  local okm, m = pcall(function() return pane[method] end)
  if okm and type(m) == 'function' then
    local ok, v = pcall(m, pane)
    if ok then return v end
  end
  local okf, v = pcall(function() return pane[field] end)
  if okf then return v end
  return nil
end
function M.adapt_domain(pane) return read(pane, 'get_domain_name', 'domain_name') end
function M.adapt_fg(pane) return read(pane, 'get_foreground_process_name', 'foreground_process_name') end
function M.adapt_cwd(pane) return read(pane, 'get_current_working_dir', 'current_working_dir') end
function M.adapt_title(pane) return read(pane, 'get_title', 'title') end

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

-- Pure: choose a process label to display. Prefer the foreground process name; fall back to the
-- pane title -- mux-domain panes on Windows report NO fg name (snapshot or live), but the title
-- carries it: the live animated Claude activity ("⠐ Verify and research..."), "repo - Lazygit", or
-- a "...\pwsh.exe" path that proc_label basenames down to "pwsh". { name, icon } | nil for empty.
function M.proc_display(fg_process_name, title, icon_map)
  local src = (fg_process_name and fg_process_name ~= '' and fg_process_name) or title
  return M.proc_label(src, icon_map)
end

-- Pure: truncate to at most `max` UTF-8 codepoints (never cuts a multibyte glyph mid-byte, so the
-- Claude spinner survives), appending '…' when shortened. Caps tab width as insurance against the
-- earlier "title bleeds into the next tab" clipping. nil/<=0 max or unmeasurable string -> unchanged.
function M.truncate(s, max)
  if not s or not max or max <= 0 then return s end
  local n = utf8.len(s)
  if not n or n <= max then return s end
  return s:sub(1, (utf8.offset(s, max + 1) or 1) - 1) .. '…'
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
  local proc_max = opts.proc_max or 24
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
  -- Live foreground process via the mux. A TabInformation snapshot leaves foreground_process_name
  -- EMPTY for mux-domain panes (the persistent `unix` mux), but the live MuxPane still answers --
  -- so nvim/lazygit/node/etc. resolve in tabs, not just plain pwsh. pcall-guarded throughout.
  local function live_fg(pane_id)
    if not (wezterm.mux and pane_id) then return nil end
    local ok, mp = pcall(wezterm.mux.get_pane, pane_id)
    if not ok or not mp then return nil end
    local ok2, n = pcall(function() return mp:get_foreground_process_name() end)
    return ok2 and n or nil
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
    -- Lead/trail spaces: tabline gives function components no padding, so without these the text
    -- butts against the powerline section separators. Empty returns above stay empty (no stray gap).
    return ' ' .. nf.dev_git .. ' ' .. gs.branch .. (gs.dirty and (' ' .. dirty_mark) or '') .. ' '
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
    local icon = h.icon and (h.icon .. ' ') or ''
    return ' ' .. icon .. (h.label or '') .. ' '
  end)

  C.focused_process = safe(function(window, pane)
    pane = pane or (window and window:active_pane())
    if not pane then return '' end
    local pl = M.proc_display(M.adapt_fg(pane), M.adapt_title(pane), proc_icons)
    return pl and M.truncate(pl.name, proc_max) or ''
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
    local fg = M.adapt_fg(pi)
    if not fg or fg == '' then fg = live_fg(pi.pane_id) end   -- mux snapshot has no fg; ask the mux
    local pl = M.proc_display(fg, M.adapt_title(pi), proc_icons)
    if not pl then return '' end
    -- Leading space: tab sections get no component separators, so each component self-separates.
    return ' ' .. (pl.icon and (pl.icon .. ' ') or '') .. M.truncate(pl.name, proc_max)
  end)

  C.tab_host_icon = safe(function(tab, pane)
    local pi = pane or (tab and tab.active_pane)
    if not pi then return '' end
    local h = M.host_of(M.adapt_domain(pi), M.adapt_fg(pi), {
      local_icon = opts.local_icon, wsl_icon = opts.wsl_icon, ssh_icon = opts.ssh_icon,
    })
    return h.icon and (' ' .. h.icon) or ''
  end)

  C.smart_dir = safe(function(tab, pane)
    local pi = pane or (tab and tab.active_pane)
    if not pi then return '' end
    local cwd = M.adapt_cwd(pi)
    if not cwd then return '' end
    local path = M.path_from_url(cwd.file_path, cwd.host)
    local dir
    if not path then                          -- remote/UNC/WSL: show the host, else the leaf dir
      dir = (cwd.host and cwd.host ~= '' and cwd.host) or M.basename(cwd.file_path)
    elseif is_remote(pi) then                 -- ssh/wsl by content: leaf dir (no local git probe)
      dir = M.basename(path)
    else                                      -- local: repo name when in a git tree, else leaf dir
      dir = M.git_toplevel(run, os.time(), path, top_cache, opts.top_ttl or 30) or M.basename(path)
    end
    if not dir or dir == '' then return '' end
    return ' ' .. dir                         -- leading space: tab components self-separate
  end)

  C.pane_count = safe(function(tab, pane)
    if not tab or not tab.panes then return '' end
    local n = #tab.panes
    if n <= 1 then return '' end
    return ' ' .. pane_glyph .. n
  end)

  return C
end

return M

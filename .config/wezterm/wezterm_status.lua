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
    local branch = first:match('^## ([^.\r\n]+)') or first:match('^## (.+)$')
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

M.basename = basename
return M

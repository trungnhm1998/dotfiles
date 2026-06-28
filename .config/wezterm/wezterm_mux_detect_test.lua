local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
package.path = here .. "/?.lua;" .. package.path
local D = require("wezterm_mux_detect")

local fails = 0
local function ok(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. (msg or "")) end end

-- Fake pane: methods accept the colon-call self and return canned values. A nil field makes the
-- getter return nil -- exactly what get_foreground_process_name() does on a mux pane.
local function pane(o)
  o = o or {}
  return {
    get_user_vars = function() return o.uv or {} end,
    get_foreground_process_name = function() return o.fg end,
    get_title = function() return o.title end,
    get_domain_name = function() return o.domain end,
  }
end

-- The five real-world cases measured via the Ctrl+Shift+I probe:
-- A: plain pwsh mux pane -- nothing owns Ctrl+Space.
local a = pane({ fg = nil, title = "pwsh.exe", domain = "unix" })
ok(not D.is_ssh_pane(a), "A plain pwsh not ssh")
ok(not D.is_wsl_pane(a), "A plain pwsh not wsl")
ok(not D.is_tmux_pane(a), "A plain pwsh not tmux")

-- B: `ssh mac` typed in pwsh -- mux hides ssh (fg nil, title pwsh.exe); wrapper sets mux_prog.
local b = pane({ fg = nil, title = "pwsh.exe", domain = "unix", uv = { mux_prog = "ssh" } })
ok(D.is_ssh_pane(b), "B typed ssh via user var")

-- C: picker-spawned ssh -- mux pane, fg nil, but title is the ROOT process ssh.exe.
local c = pane({ fg = nil, title = "ssh.exe", domain = "unix" })
ok(D.is_ssh_pane(c), "C picker ssh via title")

-- D: `wsl` typed in pwsh -- domain still unix; wrapper sets mux_prog=wsl.
local d = pane({ fg = nil, title = "pwsh.exe", domain = "unix", uv = { mux_prog = "wsl" } })
ok(D.is_wsl_pane(d), "D typed wsl via user var")
ok(not D.is_ssh_pane(d), "D wsl is not ssh")

-- E: picker WSL -- real WSL domain (the path that already worked).
local e = pane({ fg = "C:\\Program Files\\WSL\\wslhost.exe", title = "wslhost.exe", domain = "WSL:Ubuntu-24.04" })
ok(D.is_wsl_pane(e), "E wsl domain")

-- Local (non-mux) panes, e.g. mac/Linux: fg works and is authoritative.
ok(D.is_ssh_pane(pane({ fg = "/usr/bin/ssh" })), "unix fg ssh path")
ok(D.is_ssh_pane(pane({ fg = "mosh-client" })), "unix mosh-client")
ok(D.is_tmux_pane(pane({ fg = "tmux" })), "unix tmux fg")
ok(not D.is_tmux_pane(pane({ fg = "nvim" })), "unix nvim not tmux")

-- user var beats a root/stale title (typed ssh: title says pwsh, user var says ssh).
ok(D.is_ssh_pane(pane({ fg = nil, title = "pwsh.exe", uv = { mux_prog = "ssh" } })), "precedence uv > title")

-- empty user var must NOT count (wrapper cleared it on exit) -> fall through to title.
ok(not D.is_ssh_pane(pane({ fg = nil, title = "pwsh.exe", uv = { mux_prog = "" } })), "empty uv ignored")

-- getters that throw must not crash detection (pcall guards).
local boom = {
  get_user_vars = function() error("x") end,
  get_foreground_process_name = function() error("x") end,
  get_title = function() error("x") end,
  get_domain_name = function() error("x") end,
}
ok(not D.is_ssh_pane(boom), "boom ssh false, no crash")
ok(not D.is_wsl_pane(boom), "boom wsl false, no crash")

if fails == 0 then print("wezterm_mux_detect_test OK") else print(fails .. " FAILURES"); os.exit(1) end

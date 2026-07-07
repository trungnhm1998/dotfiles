-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
local opt = vim.opt
opt.listchars = {
    tab = ">-",
    trail = "~",
    extends = ">",
    precedes = "<",
    space = ".",
    eol = "↵",
    nbsp = "␣",
}
opt.list = true
opt.shiftwidth = 4
opt.softtabstop = 4
opt.tabstop = 4
opt.expandtab = true

-- Windows defaults 'fileformats' to "dos,unix", so every new file is created with CRLF.
-- Put unix first: new files save as LF; existing CRLF files still detect as dos and open
-- clean (no ^M), preserving their format until you deliberately :set ff=unix.
opt.fileformats = { "unix", "dos" }

-- Emit a terminal title so the WezTerm tab can identify this pane. WezTerm's mux hides the
-- foreground process name for mux-domain panes, so the tab falls back to the pane title -- without
-- this, an nvim tab shows nothing. Renders e.g. "nvim options.lua" (%t = filename tail).
opt.title = true
opt.titlestring = "nvim %t"

vim.g.snacks_animate = false
vim.g.autoformat = false

-- Windows: leave 'shell' on the default cmd.exe. 'shell' is plumbing (:!, system(),
-- :grep/:make pipes) and gets spawned fresh per call — pwsh boots in ~200-650 ms vs
-- cmd's ~25 ms, which made every shell-out crawl. Interactive terminals still get
-- pwsh via snacks.nvim's terminal.shell (see lua/plugins/snacks.lua).

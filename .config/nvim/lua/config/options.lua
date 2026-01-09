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
opt.tabstop = 4

vim.g.autoformat = false

-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.listchars = {
  tab = ">-",
  trail = "~",
  extends = ">",
  precedes = "<",
  space = ".",
  eol = "↵",
  nbsp = "␣",
}
vim.opt.list = true
vim.g.autoformat = false
vim.g.lazyvim_cmp = "nvim-cmp"

local path_to_workspace = ""

if vim.fn.has("win32") then
  path_to_workspace = "Z:\\My Drive\\ObsidianVaults\\"
  -- table.insert(workspaces, {
  --   name = "vault",
  --   path = "Z:\\My Drive\\ObsidianVaults",
  -- })
end

return {
  enabled = true,
  "epwalsh/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
  ft = "markdown",
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   -- refer to `:h file-pattern` for more examples
  --   "BufReadPre " .. path_to_workspace .. "\\*.md",
  --   "BufNewFile " .. path_to_workspace .. "\\*.md",
  -- },
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",
  },
  ---@module 'obsidian'
  ---@type obsidian.config.Internal
  opts = {
    workspaces = {
      {
        name = "vault",
        path = path_to_workspace,
      },
    },
    ui = { enable = false },
  },
}

if vim.fn.has("wsl") == 1 then
    return {}
end
local path_to_workspace = ""

if vim.fn.has("mac") == 1 then
    -- Use environment variable or expand home directory to avoid hardcoded username
    path_to_workspace = vim.fn.expand("~/Google Drive/My Drive/ObsidianVaults")
elseif vim.fn.has("win32") == 1 then
    path_to_workspace = "Z:\\My Drive\\ObsidianVaults\\"
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
        daily_notes = {
            -- Optional, if you keep daily notes in a separate directory.
            folder = "10.Daily",
            -- Optional, if you want to change the date format for the ID of daily notes.
            date_format = "%y%m%d",
            -- Optional, if you want to change the date format of the default alias of daily notes.
            alias_format = "%B %-d, %Y",
            -- Optional, default tags to add to each new daily note created.
            default_tags = { "daily-notes" },
            -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
            template = nil,
        },
    },
}

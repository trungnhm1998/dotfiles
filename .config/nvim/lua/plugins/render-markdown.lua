return {
    enabled = true,
    "MeanderingProgrammer/render-markdown.nvim",
    -- dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" }, -- if you use the mini.nvim suite
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" }, -- if you use standalone mini plugins
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
        checkbox = {
            enabled = true,
            render_modes = false,
            bullet = false,
            left_pad = 0,
            right_pad = 1,
            unchecked = {
                icon = "󰄱",
                highlight = "RenderMarkdownUnchecked",
                scope_highlight = nil,
            },
            checked = {
                icon = "",
                highlight = "RenderMarkdownChecked",
                scope_highlight = nil,
            },
            custom = {
                todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo", scope_highlight = nil },
                right_arrow = { raw = "[>]", rendered = "", highlight = "RenderMarkdownInfo", scope_highlight = nil },
                tilde = { raw = "[~]", rendered = "󰰱", highlight = "RenderMarkdownError", scope_highlight = nil },
                important = { raw = "[!]", rendered = "", highlight = "RenderMarkdownWarn", scope_highlight = nil },
            },
            scope_priority = nil,
        },
        code = {
            sign = true,
            width = "full",
            right_pad = 0,
        },
        heading = {
            sign = true,
        },
    },
}

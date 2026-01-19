return {
    "NickvanDyke/opencode.nvim",
    dependencies = {
        -- Required for `ask()` and `select()`.
        { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    init = function()
        -- Required for `opts.events.reload`.
        vim.o.autoread = true
    end,
    keys = {
        { "<leader>ao", nil, desc = "AI/OpenCode" },
        {
            "<leader>aoo",
            function()
                require("opencode").toggle()
            end,
            mode = { "n", "t" },
            desc = "Toggle OpenCode",
        },
        {
            "<leader>aoa",
            function()
                require("opencode").ask("@this: ", { submit = true })
            end,
            mode = { "n", "x" },
            desc = "Ask OpenCode",
        },
        {
            "<leader>aos",
            function()
                require("opencode").select()
            end,
            mode = { "n", "x" },
            desc = "Select action",
        },
        {
            "<leader>aor",
            function()
                return require("opencode").operator("@this ")
            end,
            mode = { "n", "x" },
            expr = true,
            desc = "Add range",
        },
        {
            "<C-M-u>",
            function()
                require("opencode").command("session.half.page.up")
            end,
            desc = "Scroll up",
        },
        {
            "<C-M-d>",
            function()
                require("opencode").command("session.half.page.down")
            end,
            desc = "Scroll down",
        },
    },
}

return {
    "folke/lazydev.nvim",
    ft = "lua",
    dependencies = {
        { "gonstoll/wezterm-types", lazy = true },
    },
    opts = {
        library = {
            { path = "wezterm-types", mods = { "wezterm" } },
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            { path = "LazyVim", words = { "LazyVim" } },
            { path = "snacks.nvim", words = { "Snacks" } },
            { path = "lazy.nvim", words = { "LazyVim" } },
        },
    },
}

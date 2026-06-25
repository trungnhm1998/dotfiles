-- nvim <-> Zellij Ctrl+hjkl navigation. Loads ONLY inside a Zellij session (vim.env.ZELLIJ).
-- Outside Zellij (plain Windows, or WSL + tmux) christoomey/vim-tmux-navigator owns these keys
-- instead; tmuxnav.lua suppresses its maps when ZELLIJ is set, so the two never fight.
-- Zellij UNBINDS Ctrl+hjkl (see config.kdl) so they pass through to nvim; these commands move
-- the nvim window and, at the editor edge, cross into the adjacent Zellij pane (zellij action
-- move-focus). No wasm plugin — Zellij can't detect nvim-under-pwsh on Windows (see config.kdl).
return {
    "swaits/zellij-nav.nvim",
    lazy = true,
    event = "VeryLazy",
    cond = function()
        return vim.env.ZELLIJ ~= nil
    end,
    keys = {
        { "<c-h>", "<cmd>ZellijNavigateLeft<cr>", silent = true, desc = "zellij: navigate left" },
        { "<c-j>", "<cmd>ZellijNavigateDown<cr>", silent = true, desc = "zellij: navigate down" },
        { "<c-k>", "<cmd>ZellijNavigateUp<cr>", silent = true, desc = "zellij: navigate up" },
        { "<c-l>", "<cmd>ZellijNavigateRight<cr>", silent = true, desc = "zellij: navigate right" },
    },
    opts = {},
}

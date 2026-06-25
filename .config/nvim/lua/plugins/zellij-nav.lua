-- nvim <-> Zellij Ctrl+hjkl navigation. Loads ONLY inside a Zellij session (vim.env.ZELLIJ).
-- Outside Zellij (plain Windows, or WSL + tmux) christoomey/vim-tmux-navigator owns these keys
-- instead; tmuxnav.lua suppresses its maps when ZELLIJ is set, so the two never fight.
-- Pairs with the Zellij-side vim-zellij-navigator.wasm binds in ~/.config/zellij/config.kdl:
-- the wasm forwards Ctrl+hjkl into nvim, and these commands move the nvim window, then cross
-- into the adjacent Zellij pane once you hit the editor's edge.
return {
    "swaits/zellij-nav.nvim",
    lazy = true,
    event = "VeryLazy",
    cond = function()
        return vim.env.ZELLIJ ~= nil
    end,
    keys = {
        { "<c-h>", "<cmd>ZellijNavigateLeftTab<cr>", silent = true, desc = "zellij: navigate left / tab" },
        { "<c-j>", "<cmd>ZellijNavigateDown<cr>", silent = true, desc = "zellij: navigate down" },
        { "<c-k>", "<cmd>ZellijNavigateUp<cr>", silent = true, desc = "zellij: navigate up" },
        { "<c-l>", "<cmd>ZellijNavigateRightTab<cr>", silent = true, desc = "zellij: navigate right / tab" },
    },
    opts = {},
}

return {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    -- Inside a Zellij session, zellij-nav.nvim owns <C-hjkl> (see plugins/zellij-nav.lua) so it can
    -- cross into adjacent Zellij panes. Suppress vim-tmux-navigator's own maps there so the two
    -- don't fight over the same keys; outside Zellij (incl. WSL + tmux) it maps as usual.
    init = function()
        if vim.env.ZELLIJ ~= nil then
            vim.g.tmux_navigator_no_mappings = 1
        end
    end,
}

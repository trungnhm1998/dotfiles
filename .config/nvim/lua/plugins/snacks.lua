return {
    "folke/snacks.nvim",
    -- Interactive terminals (<c-/>, Snacks.terminal) use pwsh; vim.o.shell stays
    -- cmd.exe for cheap plumbing spawns (see config/options.lua).
    opts = vim.fn.has("win32") == 1 and { terminal = { shell = "pwsh" } } or {},
}

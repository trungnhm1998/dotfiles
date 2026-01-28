return {
  {
    "vim-scripts/ReplaceWithRegister",
    keys = {
      -- operator-pending (normal mode, then motion)
      { "<leader>gr", "<Plug>ReplaceWithRegisterOperator", mode = "n", desc = "Replace with register (operator)" },
      -- whole-line
      { "<leader>grr", "<Plug>ReplaceWithRegisterLine", mode = "n", desc = "Replace line with register" },
      -- visual selection
      { "<leader>gr", "<Plug>ReplaceWithRegisterVisual", mode = "x", desc = "Replace selection with register" },
    },
  },
}

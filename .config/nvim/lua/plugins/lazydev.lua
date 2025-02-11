return {
  "folke/lazydev.nvim",
  ft = "lua",
  dependencies = {
    { "gonstoll/wezterm-types", lazy = true },
  },
  opts = {
    library = {
      { path = "wezterm-types", mods = { "wezterm" } },
    },
  },
}

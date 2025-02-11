return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    workspaces = {
      {
        name = "GDrive",
        path = "~/trung.nguyenhoangminh1998@gmail.com - Google Drive/My Drive/ObsidianVaults/",
      },
    },
    ui = { enable = false },
  },
  enabled = true,
}

print("Loading VSCode Keymaps...")
local map = vim.keymap.set
local vscode = require("vscode")
local action = vscode.action

-- Code Actions
map({ "n", "x" }, "<leader>cf", function()
    action("editor.action.formatDocument")
end, { desc = "Format Document" })
map("n", "<leader>cr", function()
    action("editor.action.rename")
end, { desc = "Rename Symbol" })

-- Buffers
-- workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup
map("n", "<leader>bb", function() action("workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup") end)
map("n", "<leader>bo", function() action("workbench.action.closeOtherEditors") end)
map("n", "<leader>bD", function() action("workbench.action.closeEditorsInGroup") end)

-- File Explorer
map("n", "<leader>e", function()
    action("workbench.action.toggleSidebarVisibility")
end, { desc = "Toggle Primary Sidebar" })
map("n", "<leader>ub", function()
    action("workbench.action.toggleSidebarVisibility")
end, { desc = "Toggle Secondary/Auxiliary Sidebar" })
map("n", "<leader>uB", function()
    action("workbench.action.toggleAuxiliaryBar")
end, { desc = "Toggle Secondary/Auxiliary Sidebar" })

-- Diagnostics Navigation
map("n", "<leader>cd", function()
    action("workbench.actions.view.problems")
end, { desc = "Show Problems" })

map("n", "]d", function()
    action("editor.action.marker.next")
end, { desc = "Next Diagnostic" })
map("n", "[d", function()
    action("editor.action.marker.prev")
end, { desc = "Prev Diagnostic" })
map("n", "]e", function()
    action("editor.action.marker.next")
end, { desc = "Next Error" })
map("n", "[e", function()
    action("editor.action.marker.prev")
end, { desc = "Prev Error" })
map("n", "]w", function()
    action("editor.action.marker.next")
end, { desc = "Next Warning" })
map("n", "[w", function()
    action("editor.action.marker.prev")
end, { desc = "Prev Warning" })

-- File Operations
map("n", "<leader>ff", function()
    action("workbench.action.quickOpen")
end, { desc = "Find Files" })
map("n", "<leader>fn", function()
    action("workbench.action.files.newUntitledFile")
end, { desc = "New File" })

-- Git/GitLens
map("n", "<leader>gg", function()
    action("workbench.view.scm")
end, { desc = "Git Status" })
map("n", "<leader>gG", function()
    action("workbench.view.scm")
end, { desc = "Git Status" })
map("n", "<leader>gl", function()
    action("git.viewHistory")
end, { desc = "Git Log" })
map("n", "<leader>gL", function()
    action("gitlens.gitCommands.history")
end, { desc = "GitLens Log" })
map("n", "<leader>gb", function()
    action("gitlens.toggleFileBlame:key")
end, { desc = "Git Blame Line" })
map("n", "<leader>gf", function()
    action("git.viewFileHistory")
end, { desc = "Git File History" })
map("n", "<leader>gF", function()
    action("gitlens.showQuickFileHistory")
end, { desc = "GitLens File History" })
map({ "n", "x" }, "<leader>gB", function()
    action("gitlens.openFileOnRemote")
end, { desc = "Git Browser" })

-- Search
map("x", "<leader>sw", function()
    action("workbench.action.findInFiles")
end, { desc = "Search Word in Files" })

-- Multi-cursor
map({ "n", "x" }, "<leader>r", function()
    vscode.with_insert(function()
        vscode.action("editor.action.refactor")
    end)
end)
-- map({ "n", "x", "i" }, "<C-d>", function()
--   vscode.with_insert(function()
--     vscode.action("editor.action.addSelectionToNextFindMatch")
--   end)
-- end)
-- abc
-- abc
-- abc
-- abc
map({ "n", "x", "i" }, "<leader>n", function()
    vscode.with_insert(function()
        vscode.action("editor.action.addSelectionToNextFindMatch")
    end)
end)

-- map({ "n", "x", "i" }, "<up>", function()
--   vscode.with_insert(function()
--     vscode.action("editor.action.insertCursorAbove")
--   end)
-- end)

-- map({ "n", "x", "i" }, "<down>", function()
--   vscode.with_insert(function()
--     vscode.action("editor.action.insertCursorBelow")
--   end)
-- end)

-- UI Toggles
map("n", "<leader>uw", function()
    action("editor.action.toggleWordWrap")
end, { desc = "Toggle Word Wrap" })
map("n", "<leader>uz", function()
    action("workbench.action.toggleZenMode")
end, { desc = "Toggle Zen Mode" })
map("n", "<leader>uZ", function()
    action("workbench.action.toggleMaximizeEditorGroup")
end, { desc = "Toggle Maximize Editor" })

-- AI
map("n", "<leader>aa", function()
    action("workbench.action.chat.open")
end, { desc = "Open AI Chat" })
map({ "n", "x" }, "<leader>aq", function()
    action("inlineChat.start")
end, { desc = "Open AI Inline Chat" })
map({ "n", "x" }, "<leader>as", function()
    action("workbench.action.chat.attachSelection")
end, { desc = "Add selection to chat" })
map({ "n", "x" }, "<leader>ab", function()
    action("workbench.action.chat.attachFile")
end, { desc = "Add file/buffer to chat" })
-- workbench.action.toggleSidebarVisibility
-- workbench.action.toggleAuxiliaryBar
-- workbench.action.toggleUnifiedSidebar

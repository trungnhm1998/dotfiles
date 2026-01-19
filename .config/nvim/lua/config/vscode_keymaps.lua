print("Loading vscode_keymaps.lua")
local map = vim.keymap.set
local vscode = require("vscode")
local call = vscode.call
local action = vscode.action

-- Editor variant configuration (extensible - follows OCP)
local editor_variants = {
    cursor = {
        detection_command = "aipopup.action.modal.generate",
        commands = {
            -- Only define commands that differ from VSCode defaults
            new_chat = "aichat.newchataction",
            inline_chat = "aipopup.action.modal.generate",
            -- send_to_chat, send_file_to_chat, etc. automatically fall back to vscode defaults
        },
    },
    antigravity = {
        detection_command = "antigravity.prioritized.chat.open",
        commands = {
            -- Only define commands that differ from VSCode defaults
            new_chat = "antigravity.prioritized.chat.open",
            inline_chat = "antigravity.prioritized.command.open",
            -- send_to_chat automatically falls back to vscode default
        },
    },
    vscode = {
        detection_command = nil, -- default fallback
        commands = {
            new_chat = "workbench.action.chat.open",
            inline_chat = "inlineChat.start",
            send_to_chat = "workbench.action.chat.attachSelection",
            send_file_to_chat = "workbench.action.chat.attachFile"
        },
    },
}

-- Detect current editor variant (deterministic order)
local function detect_editor_variant()
    -- Check in priority order: cursor, antigravity, then default to vscode
    local priority_order = { "cursor", "antigravity" }

    for _, variant in ipairs(priority_order) do
        local config = editor_variants[variant]
        if config.detection_command then
            local has_command = vscode.eval(
                string.format(
                    "var commands = await vscode.commands.getCommands(); return commands.includes('%s');",
                    config.detection_command
                )
            )
            if has_command then
                return variant
            end
        end
    end
    return "vscode" -- default fallback
end

local current_variant = detect_editor_variant()
print(string.format("Detected editor variant: %s", current_variant))

-- Helper function to get editor-specific command with fallback to vscode defaults
local function get_command(command_type)
    -- Try current variant first
    local cmd = editor_variants[current_variant].commands[command_type]

    -- Fallback to vscode default if not defined in current variant
    if not cmd and current_variant ~= "vscode" then
        cmd = editor_variants.vscode.commands[command_type]
    end

    -- Warn only if command doesn't exist anywhere
    if not cmd then
        vim.notify(
            string.format("Command '%s' not available for any editor variant", command_type),
            vim.log.levels.WARN
        )
    end

    return cmd
end

-- lsp
map({ "n" }, "gr", function () action("editor.action.goToReferences") end)

-- Code Actions
map({ "n", "x" }, "<leader>cf", function ()
    action("editor.action.formatDocument")
end, { desc = "Format Document" })
map("n", "<leader>cr", function ()
    action("editor.action.rename")
end, { desc = "Rename Symbol" })

-- Buffers
-- workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup
map("n", "<leader>bb", function () action("workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup") end)
map("n", "<leader>bo", function () action("workbench.action.closeOtherEditors") end)
map("n", "<leader>bd", function () action("workbench.action.closeActiveEditor") end)
map("n", "<leader>bD", function () action("workbench.action.closeEditorsInGroup") end)

-- File Explorer
map("n", "<leader>e", function ()
    -- action("workbench.action.toggleSidebarVisibility")
    action("workbench.view.explorer")
end, { desc = "Toggle Primary Sidebar" })
map("n", "<leader>ub", function ()
    action("workbench.action.toggleSidebarVisibility")
end, { desc = "Toggle Secondary/Auxiliary Sidebar" })
map("n", "<leader>uB", function ()
    action("workbench.action.toggleAuxiliaryBar")
end, { desc = "Toggle Secondary/Auxiliary Sidebar" })

-- Diagnostics Navigation
map("n", "<leader>cd", function ()
    action("workbench.actions.view.problems")
end, { desc = "Show Problems" })

map("n", "]d", function ()
    action("editor.action.marker.next")
end, { desc = "Next Diagnostic" })
map("n", "[d", function ()
    action("editor.action.marker.prev")
end, { desc = "Prev Diagnostic" })
map("n", "]e", function ()
    action("editor.action.marker.next")
end, { desc = "Next Error" })
map("n", "[e", function ()
    action("editor.action.marker.prev")
end, { desc = "Prev Error" })
map("n", "]w", function ()
    action("editor.action.marker.next")
end, { desc = "Next Warning" })
map("n", "[w", function ()
    action("editor.action.marker.prev")
end, { desc = "Prev Warning" })

-- File Operations
map("n", "<leader>ff", function ()
    action("workbench.action.quickOpen")
end, { desc = "Find Files" })
map("n", "<leader>fn", function ()
    action("workbench.action.files.newUntitledFile")
end, { desc = "New File" })

-- Git/GitLens
map("n", "<leader>gg", function ()
    action("workbench.view.scm")
end, { desc = "Git Status" })
map("n", "<leader>gG", function ()
    action("workbench.view.scm")
end, { desc = "Git Status" })
map("n", "<leader>gl", function ()
    action("git.viewHistory")
end, { desc = "Git Log" })
map("n", "<leader>gL", function ()
    action("gitlens.gitCommands.history")
end, { desc = "GitLens Log" })
map("n", "<leader>gb", function ()
    action("gitlens.toggleFileBlame:key")
end, { desc = "Git Blame Line" })
map("n", "<leader>gf", function ()
    action("git.viewFileHistory")
end, { desc = "Git File History" })
map("n", "<leader>gF", function ()
    action("gitlens.showQuickFileHistory")
end, { desc = "GitLens File History" })
map({ "n", "x" }, "<leader>gB", function ()
    action("gitlens.openFileOnRemote")
end, { desc = "Git Browser" })

map("n", "]h", function () action("workbench.action.editor.nextChange") end)
map("n", "[h", function () action("workbench.action.editor.previousChange") end)
-- Search
map("v", "<leader>sw", function ()
    action("actions.find")
end, { desc = "Search Word in Files" })

map("v", "<leader>sW", function ()
    action("workbench.action.findInFiles")
end, { desc = "Search Word in Files" })

map("v", "<C-f>", function ()
    action("actions.find")
end)

map("v", "<C-h>", function ()
    action("editor.action.startFindReplaceAction")
end)

map("v", "<leader>sr", function ()
    action("editor.action.startFindReplaceAction")
end)

map("v", "<leader>sR", function ()
    action("workbench.action.replaceInFiles")
end)

-- Multi-cursor
map({ "n", "x" }, "<leader>r", function ()
    vscode.with_insert(function ()
        vscode.action("editor.action.refactor")
    end)
end)
map({ "n", "x", "i" }, "<leader>n", function ()
    vscode.with_insert(function ()
        vscode.action("editor.action.addSelectionToNextFindMatch")
    end)
end)

-- UI Toggles
map("n", "<leader>uw", function ()
    action("editor.action.toggleWordWrap")
end, { desc = "Toggle Word Wrap" })
map("n", "<leader>uz", function ()
    action("workbench.action.toggleZenMode")
end, { desc = "Toggle Zen Mode" })
map("n", "<leader>uZ", function ()
    action("workbench.action.toggleMaximizeEditorGroup")
end, { desc = "Toggle Maximize Editor" })
map("n", "<leader>uu", function ()
    action("workbench.action.maximizeEditorHideSidebar")
end)

-- AI
map("n", "<leader>aa", function()
    local cmd = get_command("new_chat")
    if cmd then
        call(cmd)
    end
end, { desc = "Open AI Chat" })

map({ "n", "v" }, "<leader>aq", function()
    local cmd = get_command("inline_chat")
    if cmd then
        call(cmd)
    end
end, { desc = "Open AI Inline Chat" })

map({ "n", "v" }, "<leader>as", function()
    local cmd = get_command("send_to_chat")
    if cmd then
        call(cmd)
    end
end, { desc = "Add selection to chat" })

map({ "n", "v" }, "<leader>ab", function()
    action("workbench.action.chat.attachFile")
end, { desc = "Add file/buffer to chat" })

-- Debugging
map("n", "<leader>db", function() action("editor.debug.action.toggleBreakpoint") end, { desc = "Toggle Breakpoint" })
map("n", "<leader>dv", function() action("workbench.view.debug") end, { desc = "View Debug Panel" })
map("n", "<leader>dc", function() action("workbench.action.debug.continue") end, { desc = "Continue" })
map("n", "<leader>di", function() action("workbench.action.debug.stepInto") end, { desc = "Step Into" })
map("n", "<leader>do", function() action("workbench.action.debug.stepOut") end, { desc = "Step Out" })
map("n", "<leader>dO", function() action("workbench.action.debug.stepOver") end, { desc = "Step Over" })
map("n", "<leader>dt", function() action("workbench.action.debug.stop") end, { desc = "Terminate" })
map("n", "<leader>dd", function() action("workbench.action.debug.start") end, { desc = "Start Debugging" })
map("n", "<leader>dr", function() action("workbench.action.debug.restart") end, { desc = "Restart" })
map("n", "<leader>dP", function() action("workbench.action.debug.pause") end, { desc = "Pause" })
map("n", "<leader>dC", function() action("editor.debug.action.runToCursor") end, { desc = "Run to Cursor" })
map("n", "<leader>du", function() action("workbench.debug.action.toggleRepl") end, { desc = "Toggle Debug Console" })


map({ "n", "x" }, "<leader>wH", function () action("workbench.action.moveActiveEditorGroupLeft") end)
map({ "n", "x" }, "<leader>wJ", function () action("workbench.action.moveActiveEditorGroupDown") end)
map({ "n", "x" }, "<leader>wK", function () action("workbench.action.moveActiveEditorGroupUp") end)
map({ "n", "x" }, "<leader>wL", function () action("workbench.action.moveActiveEditorGroupRight") end)
map("n", "<leader>wx", function () action("workbench.action.moveEditorToNextGroup") end)
map("n", "<leader>wX", function () action("workbench.action.moveEditorToPreviousGroup") end)

map({ "n", "x" }, "<leader>wh", function () action("workbench.action.navigateLeft") end)
map({ "n", "x" }, "<leader>wj", function () action("workbench.action.navigateDown") end)
map({ "n", "x" }, "<leader>wk", function () action("workbench.action.navigateUp") end)
map({ "n", "x" }, "<leader>wl", function () action("workbench.action.navigateRight") end)

map("n", "<leader>wD", function () action("workbench.action.closeEditorsInGroup") end)
map("n", "<leader>wd", function () action("workbench.action.closeEditorsInGroup") end)
map("n", "<leader>wq", function () action("workbench.action.closeEditorsInGroup") end)
map("n", "<leader>wo", function () action("workbench.action.closeEditorsInOtherGroups") end)
map("n", "<leader>wv", function () action("workbench.action.splitEditor") end)
map("n", "<leader>ws", function () action("workbench.action.splitEditorDown") end)
map("n", "<leader>wT", function () action("workbench.action.moveEditorToFirstGroup") end)
map("n", "<leader>ww", function () action("workbench.action.focusNextGroup") end)
map("n", "<leader>wW", function () action("workbench.action.focusPreviousGroup") end)
map("n", "<leader>wm", function () action("workbench.action.maximizeEditorHideSidebar") end)

map("n", "<C-Up>", function () action("workbench.action.decreaseViewHeight") end)
map("n", "<C-Down>", function () action("workbench.action.increaseViewHeight") end)
map("n", "<C-Left>", function () action("workbench.action.decreaseViewWidth") end)
map("n", "<C-Right>", function () action("workbench.action.increaseViewWidth") end)
map("n", "<leader>w=", function () action("workbench.action.evenEditorWidths") end)

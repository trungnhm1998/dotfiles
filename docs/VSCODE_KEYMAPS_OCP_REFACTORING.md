# VSCode Keymaps OCP Refactoring

## Overview

This document describes the refactoring of `.config/nvim/lua/config/vscode_keymaps.lua` to follow the **Open-Closed Principle (OCP)** - making the code open for extension but closed for modification.

## Problem Statement

The original implementation used boolean variables (`is_cursor`, `is_antigravity`) and ternary operators to handle different editor variants (Cursor, Antigravity, VSCode). This approach:

- Violated OCP (required modifying existing code to add new variants)
- Duplicated command definitions across variants
- Used non-deterministic editor detection
- Lacked proper error handling for missing commands

## Solution Architecture

### 1. Configuration-Driven Design

Replaced boolean flags with an extensible configuration table:

```lua
local editor_variants = {
    cursor = {
        detection_command = "aipopup.action.modal.generate",
        commands = {
            -- Only define commands that differ from VSCode defaults
            new_chat = "aichat.newchataction",
            inline_chat = "aipopup.action.modal.generate",
            -- send_to_chat automatically falls back to vscode default
        },
    },
    antigravity = {
        detection_command = "antigravity.prioritized.chat.open",
        commands = {
            new_chat = "antigravity.prioritized.chat.open",
            inline_chat = "antigravity.prioritized.command.open",
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
```

### 2. Deterministic Editor Detection

```lua
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
```

### 3. Automatic Fallback Mechanism

```lua
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
```

### 4. Safe Keymap Execution

```lua
-- Before (with ternary operators):
map("n", "<leader>aa", function()
    call(is_cursor and "aichat.newchataction" or "workbench.action.chat.open")
end, { desc = "Open AI Chat" })

-- After (with fallback and nil checking):
map("n", "<leader>aa", function()
    local cmd = get_command("new_chat")
    if cmd then
        call(cmd)
    end
end, { desc = "Open AI Chat" })
```

## Benefits

1. **Extensible**: Add new editor variants by adding entries to `editor_variants` table
2. **DRY Principle**: No command duplication - variants only define what differs from VSCode
3. **Deterministic**: Explicit priority order for editor detection
4. **Safe**: Nil checking prevents crashes from missing commands
5. **Maintainable**: Single source of truth for default commands in `vscode.commands`
6. **Observable**: Debug logging shows detected variant

## How to Add New Commands

### Adding a command that exists in all variants:

1. Add it to `vscode.commands` (the default):

```lua
vscode = {
    commands = {
        new_chat = "workbench.action.chat.open",
        inline_chat = "inlineChat.start",
        send_to_chat = "workbench.action.chat.attachSelection",
        send_file_to_chat = "workbench.action.chat.attachFile",
        -- New command:
        explain_code = "workbench.action.chat.explainCode"
    },
}
```

2. Add the keymap:

```lua
map({ "n", "v" }, "<leader>ae", function()
    local cmd = get_command("explain_code")
    if cmd then
        call(cmd)
    end
end, { desc = "Explain Code" })
```

The command will automatically work for Cursor and Antigravity (fallback to VSCode default).

### Adding a command with variant-specific overrides:

1. Add the default to `vscode.commands`
2. Override only in variants that need different commands:

```lua
cursor = {
    detection_command = "aipopup.action.modal.generate",
    commands = {
        new_chat = "aichat.newchataction",
        inline_chat = "aipopup.action.modal.generate",
        -- Cursor uses a different command for explain:
        explain_code = "cursor.explainCode"
    },
}
```

## How to Add New Editor Variants

1. Add entry to `editor_variants`:

```lua
codeium = {
    detection_command = "codeium.command.unique",
    commands = {
        -- Only define commands that differ from VSCode defaults
        new_chat = "codeium.chat.open",
        inline_chat = "codeium.inline.start",
    },
}
```

2. Add to priority order in `detect_editor_variant()`:

```lua
local priority_order = { "cursor", "antigravity", "codeium" }
```

That's it! The fallback mechanism handles the rest.

## Testing

After modifications:

1. Check detection works:
   - Look for "Detected editor variant: [variant]" in output
   - Run `:lua print(vim.inspect(editor_variants))` to verify config

2. Test keymaps:
   - Try `<leader>aa`, `<leader>aq`, `<leader>as` in each editor
   - Verify correct commands are called

3. Check error handling:
   - Add a non-existent command to test warning system
   - Verify `vim.notify` shows appropriate warning

## Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| Configuration table over classes | Lua idiom; simpler than OOP for this use case |
| Automatic fallback to VSCode | VSCode is the base platform; reduces duplication |
| Priority-based detection | Deterministic; prevents race conditions |
| Nil checking in keymaps | Defensive programming; prevents crashes |
| Debug logging | Aids troubleshooting editor detection issues |
| `ipairs()` over `pairs()` | Deterministic iteration order |

## Related Files

- `.config/nvim/lua/config/vscode_keymaps.lua` - Main configuration file
- `AGENTS.md` - Guidelines for agents working with this codebase
- `CLAUDE.md` - Repository architecture and setup instructions

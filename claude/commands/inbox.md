---
description: File a markdown note (an existing file, or distilled from this chat) into the Obsidian vault 00.Inbox for Max to read - the human-facing twin of /wiki-capture
argument-hint: [optional: path to a .md file to file as-is; omit to distill this conversation]
allowed-tools: Read, Write, Glob, Grep, Bash
model: inherit
---

Use the **obsidian-inbox** skill to file content into Max's Obsidian vault `00.Inbox/`
so he can read and learn from it. This is NOT `/wiki-capture` (that owns `05.Wiki/`).

Input: $ARGUMENTS

- If `$ARGUMENTS` names a markdown file path, file THAT file into `00.Inbox/` as-is
  (add frontmatter if missing + the suggested-home line; leave the source in place).
- If `$ARGUMENTS` is empty, distill THIS conversation into an inbox note in Max's voice.

Follow the obsidian-inbox skill exactly: read the vault `CLAUDE.md` section 5 first,
write only inside `00.Inbox/`, and do not run git in the vault.

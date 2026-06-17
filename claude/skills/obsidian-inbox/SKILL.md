---
name: obsidian-inbox
description: Use when Max asks to put something into his Obsidian vault INBOX for him to read or learn from - "put this in my inbox", "drop this spec in obsidian", "save this to my vault to read", "add to obsidian inbox", or when he runs /inbox or /obsidian-inbox. Files a markdown note (an existing .md file, or one distilled from this conversation) into 00.Inbox in Max's voice, following the vault INBOX-FIRST procedure. NOT for capturing Claude's own durable knowledge - that is /wiki-capture into 05.Wiki. This skill only ever writes inside 00.Inbox.
---

# Obsidian Inbox - file a note into 00.Inbox for Max to read

Max wants this content in his Obsidian **Inbox** so he can read and learn from it later.
This is the human-facing twin of `/wiki-capture`: that skill owns `05.Wiki/` (Claude's
own knowledge); THIS one writes only into `00.Inbox/`, in Max's voice, for Max.

The vault root for this machine is shown in the session vault map; if it is not already
in context, read `$OBSIDIAN_VAULT` (or
`source ~/.claude/hooks/lib/obsidian-vault.sh && resolve_obsidian_vault`). All paths
below are relative to that vault root.

## Hard boundary (do not cross)
- Write ONLY inside `00.Inbox/`. Never `05.Wiki/`, never `01`-`04`, never `10.Daily`.
- This is NOT wiki capture. If what Max actually wants is to store *Claude's* durable
  knowledge, lessons, or project facts, stop and tell him that is `/wiki-capture`.
- Never run git in the vault. Writing the file is the whole job.

## Flow
1. **Read the rules + current state first** (prevents misformatted or duplicate notes):
   - The vault `CLAUDE.md` section 5 (INBOX-FIRST) and section 3 (frontmatter + naming).
   - Skim existing `00.Inbox/` filenames to match the house naming style.
2. **Detect input mode:**
   - **A markdown file path was given** (in the command arguments or Max's message):
     **copy that file as-is** into `00.Inbox/`. Keep the body verbatim; only PREPEND
     the section-3 frontmatter if the file lacks it, then add the section-5 suggested
     home line. Do NOT move or delete the source unless Max explicitly said "move".
   - **No file path:** distill THIS conversation into one (occasionally a few) atomic
     note(s) **in Max's voice** - not a transcript, not your prose - per section 5.
3. **Write into `00.Inbox/`** following section 5: frontmatter (`type`, `tags`,
   `created:` = today's date from the session context), body, `[[links]]` to related
   vault notes, and the section-5 "Suggested home" callout line reproduced exactly as
   the vault defines it (`<PARA path>` + one-line PARA reasoning). Title: sentence-like
   and descriptive, or keep the source file's own title; match existing inbox files.
4. **Do NOT touch git.** Write-only - no `git add/commit/push` in the vault. Max syncs
   the vault on his own schedule.
5. **Report**: list each note created, its path, and a one-line "why" for the PARA
   placement (teach the bucket choice). Flag any unresolved `[[links]]` as future-note
   TODOs.

Be decisive and show brief reasoning - Max is learning the PARA system, not just
collecting files.

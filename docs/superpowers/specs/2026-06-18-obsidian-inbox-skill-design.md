# Obsidian Inbox Skill + `/inbox` Command - Design

**Date:** 2026-06-18
**Repo:** dotfiles (`claude/skills`, `claude/commands`)
**Status:** Approved (brainstorming) - pending implementation plan

## Problem

Max routinely tells Claude to "put the spec file / something I learned into my
Obsidian inbox" - notes meant for *him* to read and learn from. Today this is done
ad hoc, with no consistent procedure, so it is inconsistent and easy to misroute into
the wrong place.

There is already a sibling tool for the *other* kind of capture: `/wiki-capture`
(command at `claude/commands/wiki-capture.md`) files durable knowledge into the
vault's agent-owned `05.Wiki/` zone. That is **Claude's** knowledge store. What is
missing is the human-facing twin that files into `00.Inbox/` in **Max's** voice for
**Max** to read - the PARA "INBOX-FIRST" flow defined in the vault's `CLAUDE.md`
section 5.

## Goal

A reliable, low-friction tool that drops a note into the Obsidian vault `00.Inbox/`,
following the vault's section 5 procedure, invokable two ways:

- by natural language ("put this in my inbox", "save this spec to my vault to read"), and
- by an explicit short command `/inbox`.

It handles two input modes and never collides with `/wiki-capture`.

**Non-goals:**

- No vault git commit/push at runtime (write-only, like `/wiki-capture`). Vault sync
  stays on Max's own schedule / weekly review.
- Does not write anywhere except `00.Inbox/`. Never `05.Wiki/`, never `01`-`04`.
- Not a replacement for `/wiki-capture`; the two are deliberately separate.

## Design

Hybrid: one skill holds all logic; a thin command is an ergonomic alias.

### 1. Artifacts

| File | Role |
|---|---|
| `claude/skills/obsidian-inbox/SKILL.md` | The brain. Full procedure + the auto-trigger `description` that draws the hard line vs `/wiki-capture`. |
| `claude/commands/inbox.md` | Thin shortcut. Body: invoke the `obsidian-inbox` skill with `$ARGUMENTS`. No duplicated logic (DRY). |

### 2. Runtime behavior

1. **Resolve target.** Vault root from the session vault-map / `$OBSIDIAN_VAULT`
   (same resolution `/wiki-capture` uses). Target folder is `00.Inbox/`.
2. **Read the rules first.** Read the vault `CLAUDE.md` section 5 (INBOX-FIRST) and
   section 3 (frontmatter + naming) before writing, so the note matches house format
   and the suggested-home callout line is reproduced exactly as the vault defines it
   (referenced, not hardcoded - DRY against the vault spec).
3. **Auto-detect input mode:**
   - **Path/filename given** (e.g. `/inbox docs/specs/foo-design.md`): **copy that
     file as-is** into `00.Inbox/`. Keep content verbatim; only prepend section 3
     frontmatter if missing, plus the suggested-home line. **Copy, not move** - the
     source (e.g. a project spec) stays where it is. "move" is opt-in (then delete
     source).
   - **No path:** distill *this conversation* into one (occasionally a few) atomic
     note(s) **in Max's voice**, per section 5.
4. **Format.** Frontmatter (`type`, `tags`, `created: <today>`), body, `[[links]]` to
   related notes, and the vault's section 5 suggested-home callout line
   (`<PARA path> - <one-line reasoning>`). Sentence-like descriptive title, or keep
   the source file's own title; match existing `00.Inbox/` filenames.
5. **No vault git.** Write-only. Then **report**: what was filed, where, and a
   one-line "why" for the PARA placement (teach).

### 3. Boundary vs `/wiki-capture` (collision guard)

The skill `description` is the trigger contract:

- **Fires on:** "put this in my inbox", "drop this spec in obsidian", "save this to my
  vault to read/learn", "add to obsidian inbox", and the explicit `/inbox` /
  `/obsidian-inbox`.
- **Does NOT fire for:** capturing Claude's own durable knowledge / lessons / project
  facts - that is `/wiki-capture` to `05.Wiki/`.
- **Invariant:** this skill only ever writes inside `00.Inbox/`, in Max's voice, for
  Max to read.

### 4. Deployment (one-time)

1. Create the two files under `dotfiles/claude/...`.
2. **Command:** already live - `~/.claude/commands` is a whole-dir symlink to
   `dotfiles/claude/commands` (`deploy_windows.ps1` lines 182-187). No link step.
3. **Skill symlink:** `~/.claude/skills` is a real dir with per-item links
   (`deploy_windows.ps1` lines 578-601). Create
   `~/.claude/skills/obsidian-inbox` -> `dotfiles/claude/skills/obsidian-inbox`.
   Try `SymbolicLink`; if non-elevated creation fails (no Admin/Developer Mode), fall
   back to a directory `Junction` (no elevation needed; the harness reads it
   identically and `deploy_windows.ps1` only checks `Test-Path`, so a future deploy
   leaves it as-is).
4. **Commit + push `dotfiles`** (remote is SSH `git@github.com:trungnhm1998/dotfiles.git`),
   staging only the two new paths + this spec. **No `Co-Authored-By` / AI-attribution
   trailer** (Max's git rule).
5. **Verify** (see Success criteria).

## Decisions / defaults (approved)

- **Copy, not move** for the file-input mode (non-destructive; vault section 7 safety).
- **Junction fallback** if the skill symlink needs elevation.
- Names: skill `obsidian-inbox`, command `/inbox`.
- Suggested-home marker referenced from vault section 5, not hardcoded, so both files
  stay ASCII and track the vault's own convention.

## Success criteria

- `/inbox` appears as a command; `obsidian-inbox` appears as a skill.
- Natural language "put this in my inbox" auto-invokes `obsidian-inbox` (not
  `/wiki-capture`).
- **File mode:** `/inbox <path>.md` creates `00.Inbox/<...>.md` with frontmatter +
  suggested-home line; the source file is unchanged.
- **Chat mode:** `/inbox` with no args writes one inbox note in Max's voice with
  frontmatter, `[[links]]`, and the suggested-home line.
- No write outside `00.Inbox/`; `05.Wiki/` untouched; no vault git commit.
- Skill linked into `~/.claude/skills/` (symlink or junction); dotfiles committed +
  pushed over SSH with no AI-attribution trailer.

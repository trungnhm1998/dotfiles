# Obsidian Inbox Skill + /inbox Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the human-facing twin of `/wiki-capture` - an `obsidian-inbox` skill (plus a thin `/inbox` command) that files a markdown note into the Obsidian vault `00.Inbox/` for Max to read, following the vault's INBOX-FIRST procedure.

**Architecture:** Hybrid. One skill (`claude/skills/obsidian-inbox/SKILL.md`) holds all logic and the auto-trigger description; a thin command (`claude/commands/inbox.md`) is an ergonomic alias that just invokes the skill (DRY). The command is live immediately via the whole-dir `~/.claude/commands` symlink; the skill needs a per-item symlink into `~/.claude/skills`. Runtime is write-only (no vault git).

**Tech Stack:** Markdown skill/command files (Claude Code), Windows PowerShell for symlink + git, git over SSH.

## Global Constraints

- **Repo / branch:** `C:\Users\mint\dotfiles`, branch `feat/obsidian-inbox-skill` (already created off `origin/master`; spec commit `85b6115` already present).
- **Stage EXPLICIT paths only.** The working tree carries UNRELATED in-progress WIP that must NEVER be staged: `claude/settings.json` (modified) and two untracked `docs/superpowers/*/2026-06-17-session-ledger-*` files. Every `git add` names exact paths. Never `git add -A` / `git add .`.
- **No AI-attribution trailer.** No `Co-Authored-By`, no "Generated with Claude" footer (Max's git rule).
- **Push over SSH.** Remote `origin` is `git@github.com:trungnhm1998/dotfiles.git` (already SSH).
- **ASCII only** in the two authored files - no em-dash, no emoji, no smart quotes. Reference the vault's section-5 "Suggested home" marker by pointing at the vault `CLAUDE.md`, do NOT embed its emoji/em-dash.
- **Runtime invariant the skill must encode:** write ONLY inside `00.Inbox/`; never `05.Wiki/`, `01`-`04`, or `10.Daily`; never run git in the vault.
- **Conventional Commits** for messages.

---

### Task 1: Author the skill + thin command

**Files:**
- Create: `claude/skills/obsidian-inbox/SKILL.md`
- Create: `claude/commands/inbox.md`

**Interfaces:**
- Produces: a skill named `obsidian-inbox` (invocable via the Skill tool and as `/obsidian-inbox`), and a `/inbox` command whose body invokes that skill with `$ARGUMENTS`.
- Consumes: the vault `CLAUDE.md` sections 5 and 3 at runtime (read by the skill, not at author time).

- [ ] **Step 1: Create the skill file**

Create `claude/skills/obsidian-inbox/SKILL.md` with EXACTLY this content:

```markdown
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
```

- [ ] **Step 2: Create the command file**

Create `claude/commands/inbox.md` with EXACTLY this content:

```markdown
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
```

- [ ] **Step 3: Verify both files exist and are well-formed**

Run:
```powershell
$dot = "C:\Users\mint\dotfiles"
Test-Path "$dot\claude\skills\obsidian-inbox\SKILL.md"
Test-Path "$dot\claude\commands\inbox.md"
Get-Content "$dot\claude\skills\obsidian-inbox\SKILL.md" -TotalCount 3
Select-String -Path "$dot\claude\skills\obsidian-inbox\SKILL.md" -Pattern "00\.Inbox","wiki-capture" | Select-Object -ExpandProperty Pattern -Unique
```
Expected: both `Test-Path` print `True`; the head shows `---` then `name: obsidian-inbox` then the `description:` line; the `Select-String` confirms both `00.Inbox` and `wiki-capture` appear (the boundary is encoded).

- [ ] **Step 4: Verify no Unicode slipped in**

Run:
```powershell
$dot = "C:\Users\mint\dotfiles"
$bad = Select-String -Path "$dot\claude\skills\obsidian-inbox\SKILL.md","$dot\claude\commands\inbox.md" -Pattern "[^\x00-\x7F]"
if ($bad) { "FAIL - non-ASCII found:"; $bad } else { "PASS - ASCII only" }
```
Expected: `PASS - ASCII only`. If it fails, replace the offending character with its ASCII equivalent and re-run.

- [ ] **Step 5: Commit (explicit paths only)**

```powershell
$dot = "C:\Users\mint\dotfiles"
git -C $dot add claude/skills/obsidian-inbox/SKILL.md claude/commands/inbox.md
git -C $dot status --short
```
Confirm `git status --short` lists ONLY the two new files as staged (`A`), and that `claude/settings.json` + the session-ledger docs remain UNSTAGED. Then:
```powershell
git -C $dot commit -m "feat(skills): obsidian-inbox skill + /inbox command

Human-facing twin of /wiki-capture: files a note into the vault 00.Inbox
(Max's voice, for reading) per vault CLAUDE.md section 5. Thin /inbox
command invokes the skill. Write-only; copy-not-move file mode."
```
Expected: one commit, `2 files changed`.

---

### Task 2: Link the skill into ~/.claude/skills (symlink, junction fallback)

**Files:**
- Create (filesystem link, outside the repo): `C:\Users\mint\.claude\skills\obsidian-inbox` -> `C:\Users\mint\dotfiles\claude\skills\obsidian-inbox`

**Interfaces:**
- Consumes: the skill folder created in Task 1.
- Produces: a live, discoverable `obsidian-inbox` skill in `~/.claude/skills`. Nothing to commit (the link lives under `~/.claude`, which is not a git repo).

- [ ] **Step 1: Create the link (try SymbolicLink, fall back to Junction)**

`~/.claude/skills` is a real directory with per-item links (see `deploy_windows.ps1` lines 578-601). Create just this one link. SymbolicLink needs Developer Mode or Admin; if that fails, a directory Junction needs neither and the harness reads it identically.

```powershell
$src = "C:\Users\mint\dotfiles\claude\skills\obsidian-inbox"
$dst = "C:\Users\mint\.claude\skills\obsidian-inbox"
if (Test-Path $dst) { "Already linked - leaving as-is"; (Get-Item $dst).LinkType }
else {
  try {
    New-Item -ItemType SymbolicLink -Path $dst -Value $src -ErrorAction Stop | Out-Null
    "Created SymbolicLink"
  } catch {
    Write-Output "SymbolicLink failed ($($_.Exception.Message)); falling back to Junction"
    New-Item -ItemType Junction -Path $dst -Value $src | Out-Null
    "Created Junction"
  }
}
```
Expected: prints `Created SymbolicLink` (or `Created Junction` on the fallback path).

- [ ] **Step 2: Verify the link resolves and reads back the real file**

```powershell
$dst = "C:\Users\mint\.claude\skills\obsidian-inbox"
(Get-Item $dst).LinkType
Test-Path "$dst\SKILL.md"
(Get-Content "$dst\SKILL.md" -TotalCount 2)[-1]
```
Expected: a link type (`SymbolicLink` or `Junction`); `True`; and the second line prints `name: obsidian-inbox`.

---

### Task 3: Verify discoverability and push the branch

**Files:** none created. Pushes branch `feat/obsidian-inbox-skill` to `origin`.

**Interfaces:**
- Consumes: the commit from Task 1 and the link from Task 2.
- Produces: a pushed `feat/obsidian-inbox-skill` branch on `origin`.

- [ ] **Step 1: Confirm both artifacts are live in ~/.claude**

```powershell
Test-Path "C:\Users\mint\.claude\commands\inbox.md"          # live via whole-dir symlink
Test-Path "C:\Users\mint\.claude\skills\obsidian-inbox\SKILL.md"  # live via Task 2 link
```
Expected: both `True`. (The command needed no link of its own - `~/.claude/commands` is a whole-dir symlink, `deploy_windows.ps1` lines 182-187.)

- [ ] **Step 2: Confirm the vault target the skill will write to resolves**

```powershell
"$env:OBSIDIAN_VAULT"
Test-Path "$env:OBSIDIAN_VAULT\00.Inbox"
Test-Path "$env:OBSIDIAN_VAULT\CLAUDE.md"
```
Expected: prints `C:\ObsidianVaults`; both `Test-Path` print `True` (the skill can read section 5 and write into `00.Inbox`).

- [ ] **Step 3: Confirm branch state is clean of unrelated WIP before pushing**

```powershell
$dot = "C:\Users\mint\dotfiles"
git -C $dot log --oneline -3
git -C $dot status --short
```
Expected: log shows the Task-1 `feat(skills): obsidian-inbox ...` commit on top of `85b6115 docs(skills): ...` on top of `9ce30f0 ...`. `status --short` shows ONLY the unrelated WIP still unstaged (`M claude/settings.json` + the two `??` session-ledger docs) and nothing of ours pending. If anything of ours is uncommitted, stop and commit it (explicit paths) first.

- [ ] **Step 4: Push the branch over SSH**

```powershell
$dot = "C:\Users\mint\dotfiles"
git -C $dot push -u origin feat/obsidian-inbox-skill
```
Expected: branch creates on `origin` (URL `git@github.com:trungnhm1998/dotfiles.git`), upstream set. Do NOT open a PR or merge to `master` - leave that to Max (dotfiles is his direct-merge repo).

---

## Post-implementation: live smoke test (offer, do not auto-run)

After Task 3, OFFER Max a real end-to-end check (it mutates the vault, so get a yes first):
- `/inbox` with no args - distills this very session into a `00.Inbox/` note; Max reads it and deletes if unwanted.
- `/inbox <path-to-some.md>` - files an existing markdown file as-is.

Then confirm: the note landed in `00.Inbox/` (not `05.Wiki`), has frontmatter + the suggested-home line, and the vault had no git commit made by the skill.

## Self-Review

- **Spec coverage:** artifacts (skill + thin command) = Task 1; runtime behavior is the SKILL.md body authored in Task 1 Step 1 (vault resolve, read section 5/3, auto-detect file-vs-chat, copy-not-move, frontmatter + links + suggested-home line, no vault git, report); boundary vs `/wiki-capture` = encoded in the skill description + Hard boundary section; deployment (command live via dir symlink, skill per-item symlink with junction fallback, commit + push SSH, explicit paths, no AI trailer) = Tasks 2-3 + Global Constraints; success criteria = the verification steps across Tasks 1-3 + the smoke test. No gaps.
- **Placeholder scan:** both files are given in full; all verification steps have exact commands + expected output. None.
- **Type/name consistency:** skill name `obsidian-inbox` and command `/inbox` are used identically in the skill frontmatter, the command body ("Use the **obsidian-inbox** skill"), and every task. Link source/target paths match between Task 2 create and verify.

---
name: close-session
description: Use at the end of a working session (or when /close is run, or when a Stop/PreCompact nudge fires) to capture durable knowledge into 05.Wiki AND refresh the project's .planning/continuity.md, then mark the session ledger captured. The automated close-session protocol.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Close Session — capture engine

You are running the **two-channel close-session protocol**. The vault root for this
machine is in the session-start vault map; if absent, resolve with
`source ~/.claude/hooks/lib/obsidian-vault.sh && resolve_obsidian_vault` (or `$OBSIDIAN_VAULT`).

Capture has TWO channels — keep them separate:
1. **Durable knowledge → `05.Wiki/`** (reusable conventions, gotchas, decisions WITH rationale, tool/API facts).
2. **Continuity → `<cwd>/.planning/continuity.md`** (this session's changes, decisions made, decisions pending/open, next steps).

## Flow

1. **Read current state first** (prevents duplicates):
   - `05.Wiki/CLAUDE.md` (schema) and `05.Wiki/index.md` (catalog).
   - `<cwd>/.planning/continuity.md` if it exists.

2. **Durable channel** — distil only genuinely reusable knowledge from THIS session into
   atomic ideas. Update existing wiki pages over creating new ones; correct frontmatter,
   dense `[[wikilinks]]`, a `## Sources` section. Flag contradictions with
   `> [!warning] Contradiction` instead of overwriting. Never assert an unverified Unity/C# API.
   Refresh `05.Wiki/index.md` and append a `05.Wiki/log.md` entry tagged **auto** or **manual**.
   If nothing clears the durable bar, say so plainly and write NO wiki page (still do the continuity channel).

3. **Git audit** — in the vault, stage ONLY the paths you wrote (explicit paths, never `git add -A`)
   and commit:
   ```bash
   VAULT="$(source ~/.claude/hooks/lib/obsidian-vault.sh && resolve_obsidian_vault)"
   cd "$VAULT" && git add 05.Wiki/<changed-files> 05.Wiki/index.md 05.Wiki/log.md \
     && git commit -m "wiki(auto): $(date -u +%F) <one-line summary>"
   ```
   Only vault paths go in this commit — the continuity doc (step 4) lives in the PROJECT repo, not the vault.
   If the vault is not a git repo, skip the commit and note it in your report (run scripts/init-vault-git.sh to enable).

4. **Continuity channel** — rewrite `<cwd>/.planning/continuity.md` from this template
   (create `.planning/` if needed):
   ```markdown
   # Continuity — <project>
   _Updated: <YYYY-MM-DD HH:MM> · session <id-or-unknown>_

   ## Changes this session
   - <what changed: files, features, fixes>

   ## Decisions made
   - <decision> — <rationale> [[wiki-page-if-promoted]]

   ## Decisions pending / open
   - <open question or deferred choice>

   ## Next steps
   - <concrete next action>
   ```

5. **Mark the ledger captured** so the nudges reset:
   ```bash
   bash ~/.claude/hooks/ledger-mark-captured.sh "$PWD"
   ```

6. **Report** which wiki pages you created vs updated (one-line why each), confirm the
   continuity doc path, and list any unresolved `[[links]]` as future-page TODOs.

Be decisive and show brief reasoning — Max is here to learn the system, not just collect files.

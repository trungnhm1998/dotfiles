---
name: unity-worktree-setup
description: Use when creating, listing, recycling, or removing git worktrees for a Unity project, when a second checkout of a Unity repo is needed (parallel branches, agent sessions, multiple editors), or when opening a new Unity checkout would trigger a full Library reimport. Also use to audit a Unity repo before its first worktree (Library gitignore, tracked symlinks, file: package deps, cache server reachability).
---

# Unity Worktree Setup

Unity's `Library/` is a content-addressed import cache: the worktree is cheap, the warm Library inside it is expensive (hours of import). The scripts encode the industry pattern: worktrees are persistent and recycled (never created/deleted per branch), cold Libraries are seeded by copying a warm donor, and worktree state is computed live from git instead of a hand-maintained registry.

**Run the scripts. Do not improvise `git worktree` commands or hand-rolled Library copies on a Unity repo.** Every script prints JSON to stdout and signals via exit code: parse, then relay the result.

## Invocation

Two equivalent script sets — same verbs, same JSON output, same exit codes. Pick by OS:

| OS | Runtime | Form |
|---|---|---|
| Windows | PowerShell | `& "<skill-dir>/scripts/<verb>.ps1" -PascalCase value` |
| macOS / Linux | bash (3.2+; no PowerShell required) | `bash "<skill-dir>/scripts/<verb>.sh" --kebab-case value` |

Parameter mapping (ps1 = sh): `-Branch` = `--branch`, `-BaseRef` = `--base-ref`, `-Path` = `--path`, `-RepoRoot` = `--repo-root`, `-ProjectRel` = `--project-rel`, `-DefaultBranch` = `--default-branch`, `-MinDonorMB` = `--min-donor-mb`; switches `-ForceNew` / `-NoSeed` / `-Force` = `--force-new` / `--no-seed` / `--force`.

Always use named parameters. Run from inside the target repo or pass the repo root.

## Decision table

| Intent | Verb |
|---|---|
| First worktree op on this repo/machine, or "audit/set up" | `preflight` |
| Which worktrees exist / which is free | `list-worktrees` |
| Worktree for branch X | `new-worktree` (`-Branch X` / `--branch X`) |
| `new-worktree` exited 4 | `recycle-worktree` on a listed candidate with the branch |
| Repoint an existing worktree / "done with this ticket" | `recycle-worktree` (path; optional branch) |
| Permanently delete a worktree | `remove-worktree` (confirm with user first) |

Defaults: base ref and default branch come from `origin/HEAD`; on repos whose work branches off a dev branch (e.g. `dev-june-26`), pass `-BaseRef origin/<dev-branch>` (new/recycle) and `-DefaultBranch <dev-branch>` (list). Repos with several Unity projects: pass `-ProjectRel`.

## Exit codes

| Code | Meaning | Action |
|---|---|---|
| 0 | success | relay JSON summary + `nextSteps` |
| 2 | error / blocker | report `blockers`/`error`; stop |
| 3 | unsafe: dirty tree, editor open, or unpushed work | report `issues`; only retry with `-Force`/`--force` after explicit user OK |
| 4 | warm recyclable worktree available | recycle it instead; `-ForceNew`/`--force-new` only if user insists |

## Rules

- Run `preflight` before the first worktree operation on a repo; exit 2 blockers must be fixed first.
- Recycle > create > remove. Removing a worktree destroys a warm Library.
- Never symlink or share one `Library/` between checkouts (lockfile allows one editor total; one corruption kills every checkout).
- After creating or recycling, tell the user: first Unity open validates the seeded cache and imports only the delta.
- ParrelSync / Multiplayer Play Mode clones solve same-branch multiplayer testing, not parallel branch work - do not suggest them for this.
- A localhost Unity Accelerator is optional insurance (cold imports pull artifacts), not a replacement for seeding: Shader Graph, VFX Graph, and Burst results are not cached.
- `preflight` reports both project-level (`cacheServer` per project) and per-user (`userCacheServer`) Accelerator config with live reachability. When `new-worktree` cannot seed, its `nextSteps` may include exact `-EnableCacheServer -cacheServerEndpoint` launch flags - relay them verbatim.
- Human-facing docs (setup, Accelerator guidance): README.md next to this file.

## Common mistakes

- Hand-running `git worktree remove` to "clean up" - throws away hours of import value; recycle instead.
- Creating a fresh worktree per ticket - the reimport generator these scripts exist to prevent.
- Seeding while a Unity editor is open on the donor - donor selection already skips open editors; do not bypass it with manual copies.
- Letting Unity open the new worktree before seeding finished - wait for the script to exit.
- Running the `.ps1` set on macOS/Linux - use the `.sh` set there; PowerShell is not installed.

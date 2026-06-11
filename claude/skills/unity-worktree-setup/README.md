# unity-worktree-setup

Script-driven git worktree lifecycle for Unity repos. Solves the "every new worktree
cold-imports the whole project" problem by treating worktrees as persistent, recycled
checkouts and seeding cold Library folders by copying a warm one. Dual-runtime: the
same five verbs exist as PowerShell (Windows) and bash 3.2 (macOS/Linux - no
PowerShell required). Designed so a fast/small model (or a human) just runs the
scripts; all judgment lives in script logic, JSON output, and exit codes.

## Why it works

- Unity's `Library/` is a content-addressed import cache (Asset Database v2):
  artifacts are keyed by source hash + importer settings, NOT by path or branch.
- So a warm Library is transferable (copy it, next open imports only the delta)
  and survives branch rotation (switching branches re-imports only the diff).
- The worktree is cheap; the warm Library inside it is the expensive thing.
- Therefore: recycle worktrees instead of deleting them, copy a Library instead of
  re-importing, and compute worktree state from git instead of a registry file.

## Quickstart

Windows (PowerShell):

```powershell
$S = "$HOME\.claude\skills\unity-worktree-setup\scripts"
& "$S\preflight.ps1"                                   # first time on a repo
& "$S\new-worktree.ps1" -Branch feature/my-thing       # worktree for a branch
& "$S\recycle-worktree.ps1" -Path ..\Repo-wt-old -Branch feature/next-thing
```

macOS / Linux (bash):

```bash
S="$HOME/.claude/skills/unity-worktree-setup/scripts"
bash "$S/preflight.sh"
bash "$S/new-worktree.sh" --branch feature/my-thing
bash "$S/recycle-worktree.sh" --path ../Repo-wt-old --branch feature/next-thing
```

With Claude Code, just ask ("set up a worktree for bugfix/FH-1234") - SKILL.md maps
intent to these scripts.

Run from anywhere inside the target repo, or pass `-RepoRoot` / `--repo-root`.
On repos whose work branches off a dev branch (not origin/HEAD), pass
`-BaseRef origin/<dev-branch>` (new/recycle) and `-DefaultBranch <dev-branch>`
(list). Repos with several Unity projects: `-ProjectRel <dir>`.

## Verbs

| Verb | What it does |
|---|---|
| `preflight` | Read-only audit: Unity project roots, Library gitignore (probes a file INSIDE Library - dir patterns + negations fool check-ignore on the bare dir), tracked symlinks vs core.symlinks on Windows, `file:` manifest deps that escape the repo, project AND per-user Accelerator config with live TCP reachability, disk budget. |
| `list-worktrees` | The registry, computed from git: branch/detached, dirty count, merged-into-default, editor-open (`Temp/UnityLockfile`), Library warmth, and a derived `recyclable` flag. |
| `new-worktree` | Creates a sibling worktree (`<repo>-wt-<branch-slug>`), but first refuses with exit 4 if a warm recyclable worktree exists. Seeds Library from the leanest warm donor (skips editor-open checkouts and stubs below `-MinDonorMB`, default 200). |
| `recycle-worktree` | Repoints an existing worktree: refuses dirty trees / open editors, then parks detached at the base ref and optionally creates the next branch. Library stays warm. |
| `remove-worktree` | Guarded teardown; refuses dirty / unpushed / editor-open without `-Force`. Removal destroys a warm Library - prefer recycle. |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success - JSON result on stdout |
| 2 | error / blocker (preflight blockers, bad args, git failure) |
| 3 | unsafe: dirty tree, editor open, or unpushed work - fix or pass `-Force` deliberately |
| 4 | a warm recyclable worktree exists - recycle it instead (or `-ForceNew`) |

## Unity Accelerator: when do I actually want it?

Short version: while a warm sibling checkout exists on your machine, you do not need
it - seed-by-copy is faster and transfers MORE (Accelerator never caches Shader
Graph imports, VFX Graph imports, or Burst compilation; a Library copy carries all
of them).

Use an Accelerator when there is no warm donor to copy from:

- a fresh machine or fresh clone with zero warm checkouts;
- CI runners doing clean imports;
- many unrelated Unity projects that should share one artifact cache;
- a team sharing imports over LAN.

Setup (once): install the Accelerator service (default port 10080), then configure
it PER-USER in `Unity > Settings > Asset Pipeline` (Cache Server Mode = Enabled,
IP = `127.0.0.1:10080`, plus a per-project namespace prefix). Per-user config serves
every project and worktree on the machine and commits nothing to git.

How the skill cooperates:

- `preflight` reports both configs and live reachability:
  - project-level: `ProjectSettings/EditorSettings.asset` (`m_CacheServerMode`:
    0 = as-preferences, 1 = enabled, 2 = disabled; `m_CacheServerEndpoint`). A
    committed endpoint that is unreachable from your machine is flagged - that
    silently degrades every cold import to a full local recompute.
  - per-user: EditorPrefs `CacheServer2Mode` / `CacheServer2IPAddress` (registry on
    Windows, plist on macOS, unity3d prefs XML on Linux). Quirk verified from Unity
    source: the mode enum is `{ Enabled = 0, Disabled = 1 }`.
- `new-worktree` falls back gracefully: when no warm donor Library exists it checks
  for a configured Accelerator (project config first, then per-user), TCP-tests it,
  and puts the verdict in `nextSteps` - including the exact one-shot launch
  override when reachable:
  `Unity -projectPath <path> -EnableCacheServer -cacheServerEndpoint <host:port>`

## Safety rules

- Never symlink or share one `Library/` between checkouts: the lockfile allows one
  editor total, and one corruption kills every checkout. Transfer by copy only.
- Recycle > create > remove.
- All editors must be closed on a donor checkout while its Library is copied
  (donor selection already skips editor-open checkouts).
- ParrelSync / Multiplayer Play Mode solve same-branch multiplayer testing, not
  parallel branch work - different tool.

## Layout

```
unity-worktree-setup/
  SKILL.md        # agent-facing dispatch (intent -> verb -> exit code)
  README.md       # this file (human-facing)
  scripts/
    _lib.ps1  _lib.sh            # shared helpers
    preflight.ps1/.sh  list-worktrees.ps1/.sh  new-worktree.ps1/.sh
    recycle-worktree.ps1/.sh  remove-worktree.ps1/.sh
```

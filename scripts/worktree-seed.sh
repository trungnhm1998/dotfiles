#!/usr/bin/env bash
# Seed local-only files from a repo's main worktree into a fresh git worktree.
# Reads <root>/.worktreeinclude (untracked, one literal path per line) and copies
# each listed file/dir root->dest. One-way, idempotent, safe to double-fire
# (Claude native copy + this hook + a manual run). Missing manifest = silent no-op.
#
# Usage:
#   worktree-seed.sh [<dest-worktree-path>]   seed one worktree
#   worktree-seed.sh --all                    re-push to every worktree of the repo
#
# NOT `set -e`: per-entry failures warn and continue (partial seed beats aborted seed).
set -u

warn() { printf 'worktree-seed: %s\n' "$1" >&2; }

# Physical absolute form of a dir (resolves D:\ vs /d/, symlinks, trailing slash)
# so root==dest comparison is reliable across git-bash mounts.
normalize() { ( cd "$1" 2>/dev/null && pwd -P ); }

# Root = $ORCA_ROOT_PATH, else the main worktree (first porcelain "worktree" line).
resolve_root() {
  if [ -n "${ORCA_ROOT_PATH:-}" ]; then
    printf '%s\n' "$ORCA_ROOT_PATH"
    return 0
  fi
  git worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{ print substr($0, 10); exit }'
}

# Copy every manifest entry from root into one dest worktree.
seed_one() {
  local root="$1" dest="$2"
  local manifest="$root/.worktreeinclude"
  local root_p dest_p raw entry src parent count=0

  dest_p="$(normalize "$dest")"
  if [ -z "$dest_p" ]; then
    warn "dest does not exist: $dest"
    return 1
  fi
  root_p="$(normalize "$root")"
  if [ "$root_p" = "$dest_p" ]; then
    warn "refusing to seed root into itself: $dest"
    return 1
  fi

  while IFS= read -r raw || [ -n "$raw" ]; do
    entry="${raw%$'\r'}"                          # strip trailing CR (CRLF manifest)
    entry="${entry#"${entry%%[![:space:]]*}"}"    # left-trim whitespace
    entry="${entry%"${entry##*[![:space:]]}"}"    # right-trim whitespace
    entry="${entry%/}"                            # strip trailing slash (dir entries)
    [ -z "$entry" ] && continue
    case "$entry" in
      \#*)                          continue ;;                                  # comment
      /*)                           warn "skip absolute path: $entry"; continue ;;
      [A-Za-z]:[/\\]*)              warn "skip absolute path: $entry"; continue ;; # Windows drive
      *..*)                         warn "skip path with ..: $entry"; continue ;;
      .claude/worktrees|.claude/worktrees/*) warn "skip recursion guard: $entry"; continue ;;
    esac
    src="$root/$entry"
    [ -e "$src" ] || continue                     # absent under root -> silent skip
    parent="${dest}/${entry}"
    parent="${parent%/*}"
    if ! mkdir -p "$parent" 2>/dev/null; then
      warn "mkdir failed: $parent"
      continue
    fi
    rm -rf "${dest:?}/${entry}" 2>/dev/null
    if cp -RL "$src" "$dest/$entry" 2>/dev/null; then
      count=$((count + 1))
    else
      warn "copy failed: $entry"
    fi
  done < "$manifest"

  printf 'worktree-seed: seeded %d items -> %s\n' "$count" "$dest"
  return 0
}

main() {
  local root manifest dest root_p

  root="$(resolve_root)"
  if [ -z "$root" ] || [ ! -d "$root" ]; then
    warn "cannot resolve repo root (not inside a git worktree?)"
    exit 1
  fi
  manifest="$root/.worktreeinclude"
  if [ ! -f "$manifest" ]; then
    [ -t 1 ] && printf 'worktree-seed: no .worktreeinclude at %s (nothing to do)\n' "$root"
    exit 0
  fi

  if [ "${1:-}" = "--all" ]; then
    root_p="$(normalize "$root")"
    git -C "$root" worktree list --porcelain 2>/dev/null \
      | awk '/^worktree /{ print substr($0, 10) }' \
      | while IFS= read -r wt; do
          [ "$(normalize "$wt")" = "$root_p" ] && continue
          seed_one "$root" "$wt"
        done
    exit 0
  fi

  dest="${1:-${ORCA_WORKTREE_PATH:-}}"
  if [ -z "$dest" ]; then
    dest="$(git rev-parse --show-toplevel 2>/dev/null)"
  fi
  if [ -z "$dest" ]; then
    warn "no dest worktree (pass a path, set \$ORCA_WORKTREE_PATH, or run inside a worktree)"
    exit 1
  fi
  seed_one "$root" "$dest"
  exit $?
}

main "$@"

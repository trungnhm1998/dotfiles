#!/usr/bin/env bash
# remove-worktree.sh - guarded teardown. Deleting a worktree throws away its warm Library;
# prefer recycle-worktree.sh. Refuses dirty trees / unpushed branches / open editors without --force.
# Exit: 0 removed, 2 error, 3 unsafe without --force.
set -u
. "$(cd "$(dirname "$0")" && pwd)/_lib.sh"

WT_PATH=''; PROJECT_REL=''; FORCE=0
while [ $# -gt 0 ]; do
    case $1 in
        --path) WT_PATH=$2; shift 2 ;;
        --project-rel) PROJECT_REL=$2; shift 2 ;;
        --force) FORCE=1; shift ;;
        *) die_json 2 "{\"error\":\"unknown flag: $(json_escape "$1")\"}" ;;
    esac
done
[ -z "$WT_PATH" ] && die_json 2 '{"error":"--path is required"}'
[ -d "$WT_PATH" ] || die_json 2 "{\"error\":\"no such path: $(json_escape "$WT_PATH")\"}"
inside=$(git -C "$WT_PATH" rev-parse --is-inside-work-tree 2>/dev/null || true)
[ "$inside" = "true" ] || die_json 2 "{\"error\":\"$(json_escape "$WT_PATH") is not a git worktree\"}"

main_root=$(worktree_paths "$WT_PATH" | head -n 1)
if [ "$(norm_path "$main_root")" = "$(norm_path "$WT_PATH")" ]; then
    die_json 2 '{"error":"refusing to remove the main checkout"}'
fi

[ -z "$PROJECT_REL" ] && PROJECT_REL=$(first_project_rel "$WT_PATH")
[ -z "$PROJECT_REL" ] && PROJECT_REL='.'
proj=$(project_dir_of "$WT_PATH" "$PROJECT_REL")

unsafe=()
editor_open "$proj" && unsafe+=('a Unity editor has this project open')
dirty=$(dirty_count "$WT_PATH")
[ "$dirty" -gt 0 ] && unsafe+=("uncommitted changes ($dirty files)")
branch=$(branch_of "$WT_PATH")
if [ -n "$branch" ]; then
    if unpushed=$(git -C "$WT_PATH" rev-list --count "origin/$branch..HEAD" 2>/dev/null); then
        [ "$unpushed" -gt 0 ] && unsafe+=("branch '$branch' has $unpushed unpushed commits")
    else
        unsafe+=("branch '$branch' has no upstream (never pushed)")
    fi
fi
if [ "${#unsafe[@]}" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
    die_json 3 "{\"error\":\"unsafe to remove without --force\",\"issues\":$(json_str_array "${unsafe[@]}"),\"hint\":\"a removed worktree loses its warm Library (hours of import value) - consider recycle-worktree.sh instead\"}"
fi

if [ "$FORCE" -eq 1 ]; then
    git -C "$main_root" worktree remove --force "$WT_PATH" >/dev/null 2>&1
else
    git -C "$main_root" worktree remove "$WT_PATH" >/dev/null 2>&1
fi
if [ $? -ne 0 ]; then
    die_json 2 '{"error":"git worktree remove failed (Library or Temp may be locked by another process)"}'
fi
git -C "$main_root" worktree prune >/dev/null 2>&1 || true

note_json=null
[ -n "$branch" ] && note_json="\"local branch '$(json_escape "$branch")' still exists; delete with: git branch -D $(json_escape "$branch")\""
br_json=null; [ -n "$branch" ] && br_json="\"$(json_escape "$branch")\""
die_json 0 "{\"action\":\"removed\",\"path\":\"$(json_escape "$WT_PATH")\",\"branch\":$br_json,\"note\":$note_json}"

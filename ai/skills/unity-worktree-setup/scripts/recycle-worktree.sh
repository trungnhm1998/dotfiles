#!/usr/bin/env bash
# recycle-worktree.sh - point an existing warm worktree at new work (Library untouched).
# Exit: 0 recycled, 2 error, 3 unsafe (dirty tree or editor open) - never discards work.
set -u
. "$(cd "$(dirname "$0")" && pwd)/_lib.sh"

WT_PATH=''; BRANCH=''; BASE_REF=''; PROJECT_REL=''
while [ $# -gt 0 ]; do
    case $1 in
        --path) WT_PATH=$2; shift 2 ;;
        --branch) BRANCH=$2; shift 2 ;;
        --base-ref) BASE_REF=$2; shift 2 ;;
        --project-rel) PROJECT_REL=$2; shift 2 ;;
        *) die_json 2 "{\"error\":\"unknown flag: $(json_escape "$1")\"}" ;;
    esac
done
[ -z "$WT_PATH" ] && die_json 2 '{"error":"--path is required"}'
[ -d "$WT_PATH" ] || die_json 2 "{\"error\":\"no such path: $(json_escape "$WT_PATH")\"}"
inside=$(git -C "$WT_PATH" rev-parse --is-inside-work-tree 2>/dev/null || true)
[ "$inside" = "true" ] || die_json 2 "{\"error\":\"$(json_escape "$WT_PATH") is not a git worktree\"}"

default_br=$(default_branch "$WT_PATH" || true)
if [ -z "$BASE_REF" ]; then
    [ -z "$default_br" ] && die_json 2 '{"error":"no --base-ref given and default branch undetectable"}'
    BASE_REF="origin/$default_br"
fi
[ -z "$PROJECT_REL" ] && PROJECT_REL=$(first_project_rel "$WT_PATH")
[ -z "$PROJECT_REL" ] && PROJECT_REL='.'
proj=$(project_dir_of "$WT_PATH" "$PROJECT_REL")

if [ "$(dirty_count "$WT_PATH")" -gt 0 ]; then
    dirty=()
    while IFS= read -r line; do dirty+=("$line"); done <<EOF
$(git -C "$WT_PATH" status --porcelain | head -n 20)
EOF
    die_json 3 "{\"error\":\"worktree has uncommitted changes - commit, stash, or clean them first\",\"dirtyFiles\":$(json_str_array ${dirty[@]+"${dirty[@]}"})}"
fi
if editor_open "$proj"; then
    die_json 3 '{"error":"a Unity editor has this project open (Temp/UnityLockfile present) - close it first"}'
fi

prev=$(branch_of "$WT_PATH")
git -C "$WT_PATH" fetch --prune >/dev/null 2>&1 || true
if ! git -C "$WT_PATH" switch --detach "$BASE_REF" >/dev/null 2>&1; then
    die_json 2 "{\"error\":\"git switch --detach $(json_escape "$BASE_REF") failed\"}"
fi

new_branch_json=null
if [ -n "$BRANCH" ]; then
    if git -C "$WT_PATH" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
        die_json 2 "{\"error\":\"branch '$(json_escape "$BRANCH")' already exists; worktree left parked at $(json_escape "$BASE_REF")\"}"
    fi
    if ! git -C "$WT_PATH" switch -c "$BRANCH" >/dev/null 2>&1; then
        die_json 2 "{\"error\":\"git switch -c $(json_escape "$BRANCH") failed; worktree left parked at $(json_escape "$BASE_REF")\"}"
    fi
    new_branch_json="\"$(json_escape "$BRANCH")\""
fi

prev_json=null; [ -n "$prev" ] && prev_json="\"$(json_escape "$prev")\""
die_json 0 "{\"action\":\"recycled\",\"path\":\"$(json_escape "$WT_PATH")\",\"parkedAt\":\"$(json_escape "$BASE_REF")\",\"previousBranch\":$prev_json,\"branch\":$new_branch_json,\"note\":\"Library kept warm - next Unity open imports only the branch delta\"}"

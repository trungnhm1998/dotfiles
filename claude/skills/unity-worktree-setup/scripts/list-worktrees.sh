#!/usr/bin/env bash
# list-worktrees.sh - computed worktree registry (replaces hand-maintained slot files).
# Exit: 0. Output: JSON; recyclable=true rows are safe to point at new work.
set -u
. "$(cd "$(dirname "$0")" && pwd)/_lib.sh"

REPO=''; DEFAULT_BR=''; PROJECT_REL=''
while [ $# -gt 0 ]; do
    case $1 in
        --repo-root) REPO=$2; shift 2 ;;
        --default-branch) DEFAULT_BR=$2; shift 2 ;;
        --project-rel) PROJECT_REL=$2; shift 2 ;;
        *) die_json 2 "{\"error\":\"unknown flag: $(json_escape "$1")\"}" ;;
    esac
done
if [ -z "$REPO" ]; then REPO=$(repo_root || true); fi
[ -z "$REPO" ] && die_json 2 '{"error":"not inside a git repository"}'
[ -z "$DEFAULT_BR" ] && DEFAULT_BR=$(default_branch "$REPO" || true)
[ -z "$PROJECT_REL" ] && PROJECT_REL=$(first_project_rel "$REPO")
[ -z "$PROJECT_REL" ] && PROJECT_REL='.'

rows=''
while IFS= read -r wt; do
    [ -z "$wt" ] && continue
    proj=$(project_dir_of "$wt" "$PROJECT_REL")
    br=$(branch_of "$wt")
    detached=false; [ -z "$br" ] && detached=true
    dirty=$(dirty_count "$wt")
    merged=false; merged_into "$wt" "$DEFAULT_BR" && merged=true
    ed=false; editor_open "$proj" && ed=true
    warm=false; [ -d "$proj/Library" ] && warm=true
    rec=false; is_recyclable "$wt" "$PROJECT_REL" "$DEFAULT_BR" && rec=true
    br_json=null; [ -n "$br" ] && br_json="\"$(json_escape "$br")\""
    [ -n "$rows" ] && rows="$rows,"
    rows="$rows{\"path\":\"$(json_escape "$wt")\",\"branch\":$br_json,\"detached\":$detached,\"dirtyFiles\":$dirty,\"mergedIntoDefault\":$merged,\"editorOpen\":$ed,\"libraryWarm\":$warm,\"projectDir\":\"$(json_escape "$proj")\",\"recyclable\":$rec}"
done <<EOF
$(worktree_paths "$REPO")
EOF

db_json=null; [ -n "$DEFAULT_BR" ] && db_json="\"$(json_escape "$DEFAULT_BR")\""
die_json 0 "{\"repoRoot\":\"$(json_escape "$REPO")\",\"defaultBranch\":$db_json,\"projectRel\":\"$(json_escape "$PROJECT_REL")\",\"worktrees\":[$rows]}"

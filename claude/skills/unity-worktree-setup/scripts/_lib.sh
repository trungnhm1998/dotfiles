#!/usr/bin/env bash
# _lib.sh - shared helpers for unity-worktree-setup scripts. Source only.
# bash 3.2 compatible (macOS default bash).
set -u

json_escape() {
    local s=${1-}
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\t'/\\t}
    s=${s//$'\r'/}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

# json_str_array a b c -> ["a","b","c"]
json_str_array() {
    local out='' item
    for item in "$@"; do
        [ -n "$out" ] && out="$out,"
        out="$out\"$(json_escape "$item")\""
    done
    printf '[%s]' "$out"
}

die_json() { # $1 exit code, $2 json
    printf '%s\n' "$2"
    exit "$1"
}

repo_root() { git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null; }

# normalize to a comparable absolute path (Git Bash: C:/x and /c/x must compare equal)
norm_path() { (cd "$1" 2>/dev/null && pwd); }

default_branch() {
    local repo=$1 ref c
    ref=$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
    if [ -n "$ref" ]; then printf '%s' "${ref#origin/}"; return 0; fi
    for c in main master develop; do
        if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$c" 2>/dev/null; then
            printf '%s' "$c"; return 0
        fi
    done
    return 1
}

# Unity project dirs relative to checkout root, one per line ('.' for repo root)
unity_project_rels() {
    git -C "$1" ls-files '*ProjectSettings/ProjectVersion.txt' | while IFS= read -r f; do
        dirname "$(dirname "$f")"
    done
}

first_project_rel() { unity_project_rels "$1" | head -n 1; }

project_dir_of() { # $1 checkout, $2 rel
    if [ "$2" = "." ]; then printf '%s' "$1"; else printf '%s/%s' "$1" "$2"; fi
}

dir_size_bytes() {
    local p=$1 kb
    [ -d "$p" ] || { printf '0'; return; }
    kb=$(du -sk "$p" 2>/dev/null | awk '{print $1}')
    if [ -n "$kb" ]; then printf '%s' $((kb * 1024)); else printf '%s' -1; fi
}

# Unity holds Temp/UnityLockfile while an editor has the project open
editor_open() { [ -e "$1/Temp/UnityLockfile" ]; }

worktree_paths() { git -C "$1" worktree list --porcelain | sed -n 's/^worktree //p'; }

branch_of() { git -C "$1" branch --show-current 2>/dev/null; }

dirty_count() { git -C "$1" status --porcelain 2>/dev/null | grep -c .; }

merged_into() { # $1 checkout, $2 default branch (may be empty)
    [ -n "${2:-}" ] && git -C "$1" merge-base --is-ancestor HEAD "origin/$2" 2>/dev/null
}

# recyclable = clean + no editor + (detached or merged into default)
is_recyclable() { # $1 checkout, $2 projectRel, $3 defaultBranch
    local proj br
    proj=$(project_dir_of "$1" "$2")
    [ "$(dirty_count "$1")" -eq 0 ] || return 1
    editor_open "$proj" && return 1
    br=$(branch_of "$1")
    [ -z "$br" ] && return 0
    merged_into "$1" "${3:-}"
}

tcp_reachable() { # $1 host, $2 port, $3 timeout sec
    local t=${3:-3} pid i=0 max
    if command -v nc >/dev/null 2>&1; then
        nc -z -w "$t" "$1" "$2" >/dev/null 2>&1
        return $?
    fi
    ( exec 3<>"/dev/tcp/$1/$2" ) >/dev/null 2>&1 &
    pid=$!; max=$((t * 10))
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt "$max" ]; do sleep 0.1; i=$((i + 1)); done
    if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; return 1; fi
    wait "$pid"
}

copy_library() { # $1 src, $2 dst
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$1/" "$2/"
    else
        mkdir -p "$2" && cp -a "$1/." "$2/"
    fi
}

# leanest warm donor Library: prints "library|bytes|checkout" or nothing
select_donor() { # $1 repo, $2 projectRel, $3 minDonorMB, $4 excludePath(normalized, optional)
    local best_lib='' best_bytes='' best_co='' wt proj lib size
    local min_bytes=$(($3 * 1024 * 1024))
    while IFS= read -r wt; do
        [ -n "${4:-}" ] && [ "$(norm_path "$wt")" = "$4" ] && continue
        proj=$(project_dir_of "$wt" "$2")
        lib="$proj/Library"
        [ -d "$lib" ] || continue
        editor_open "$proj" && continue
        size=$(dir_size_bytes "$lib")
        [ "$size" -lt "$min_bytes" ] && continue
        if [ -z "$best_bytes" ] || [ "$size" -lt "$best_bytes" ]; then
            best_lib=$lib; best_bytes=$size; best_co=$wt
        fi
    done <<EOF
$(worktree_paths "$1")
EOF
    [ -n "$best_lib" ] && printf '%s|%s|%s' "$best_lib" "$best_bytes" "$best_co"
}

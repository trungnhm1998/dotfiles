#!/usr/bin/env bash
# preflight.sh - read-only audit of a Unity repo before worktree operations.
# Exit: 0 ok, 2 blockers found. Output: JSON on stdout.
set -u
. "$(cd "$(dirname "$0")" && pwd)/_lib.sh"

REPO=''; TCP_TIMEOUT=3
while [ $# -gt 0 ]; do
    case $1 in
        --repo-root) REPO=$2; shift 2 ;;
        --tcp-timeout-sec) TCP_TIMEOUT=$2; shift 2 ;;
        *) die_json 2 "{\"error\":\"unknown flag: $(json_escape "$1")\"}" ;;
    esac
done
if [ -z "$REPO" ]; then REPO=$(repo_root || true); fi
[ -z "$REPO" ] && die_json 2 '{"blockers":["not inside a git repository"]}'

blockers=(); warnings=()
is_win=0; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) is_win=1 ;; esac

rels=$(unity_project_rels "$REPO")
[ -z "$rels" ] && blockers+=('no tracked ProjectSettings/ProjectVersion.txt found - not a Unity repo?')

default_br=$(default_branch "$REPO" || true)
[ -z "$default_br" ] && warnings+=('could not detect default branch from origin')

symlink_count=$(git -C "$REPO" ls-files -s | grep -c '^120000' || true)
core_symlinks=$(git -C "$REPO" config --get core.symlinks 2>/dev/null || true)
if [ "$symlink_count" -gt 0 ] && [ "$is_win" -eq 1 ] && [ "$core_symlinks" != "true" ]; then
    blockers+=("$symlink_count tracked symlinks but core.symlinks!=true on Windows - worktree checkouts would materialize them as text files")
fi

projects_json=''
max_lib=0
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    proj=$(project_dir_of "$REPO" "$rel")

    version=$(head -n 1 "$proj/ProjectSettings/ProjectVersion.txt" | sed 's/m_EditorVersion:[[:space:]]*//' | tr -d '\r')

    # probe a file INSIDE Library: dir patterns + negation lines make check-ignore
    # on the bare directory report "not ignored" even when contents are
    if [ "$rel" = "." ]; then probe='Library/__wtprobe__'; else probe="$rel/Library/__wtprobe__"; fi
    if git -C "$REPO" check-ignore -q "$probe" 2>/dev/null; then lib_ignored=true; else
        lib_ignored=false
        blockers+=("$rel/Library is NOT gitignored")
    fi

    # file: package deps that are absolute or climb out of the repo break in worktrees
    risks=()
    manifest="$proj/Packages/manifest.json"
    if [ -f "$manifest" ]; then
        # depth of Packages dir below repo root: '.' -> 1, 'Project' -> 2, 'A/B' -> 3
        if [ "$rel" = "." ]; then depth=1; else depth=$(($(printf '%s' "$rel" | awk -F/ '{print NF}') + 1)); fi
        for dep in $(grep -o '"file:[^"]*"' "$manifest" | sed 's/^"file://; s/"$//'); do
            case $dep in
                /*|[A-Za-z]:*) risks+=("absolute: $dep") ;;
                *)
                    updirs=$(printf '%s' "$dep" | awk -F/ '{n=0; for (i=1; i<=NF; i++) if ($i == "..") n++; print n}')
                    [ "$updirs" -gt "$depth" ] && risks+=("escapes repo: $dep")
                    ;;
            esac
        done
        if [ "${#risks[@]}" -gt 0 ]; then
            warnings+=("$rel/Packages/manifest.json has file: deps that will not resolve in a worktree: ${risks[*]}")
        fi
    fi

    # cache server (Accelerator) config + live reachability
    cache_mode=null; cache_endpoint=null; cache_reachable=null
    es="$proj/ProjectSettings/EditorSettings.asset"
    if [ -f "$es" ]; then
        mode_num=$(sed -n 's/.*m_CacheServerMode:[[:space:]]*\([0-9]\).*/\1/p' "$es" | head -n 1)
        case ${mode_num:-} in
            0) cache_mode='"as-preferences"' ;;
            1) cache_mode='"enabled"' ;;
            2) cache_mode='"disabled"' ;;
        esac
        endpoint=$(sed -n 's/.*m_CacheServerEndpoint:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$es" | head -n 1 | tr -d '\r')
        if [ -n "${endpoint:-}" ]; then
            cache_endpoint="\"$(json_escape "$endpoint")\""
            if [ "$cache_mode" != '"disabled"' ] && printf '%s' "$endpoint" | grep -q ':[0-9][0-9]*$'; then
                host=${endpoint%:*}; port=${endpoint##*:}
                if tcp_reachable "$host" "$port" "$TCP_TIMEOUT"; then cache_reachable=true; else
                    cache_reachable=false
                    warnings+=("$rel cache server $endpoint is configured but unreachable - cold imports will be full local recomputes")
                fi
            fi
        fi
    fi

    lib="$proj/Library"
    lib_exists=false; [ -d "$lib" ] && lib_exists=true
    lib_bytes=$(dir_size_bytes "$lib")
    [ "$lib_bytes" -gt "$max_lib" ] && max_lib=$lib_bytes
    ed_open=false; editor_open "$proj" && ed_open=true

    [ -n "$projects_json" ] && projects_json="$projects_json,"
    projects_json="$projects_json{\"projectRel\":\"$(json_escape "$rel")\",\"unityVersion\":\"$(json_escape "$version")\",\"libraryIgnored\":$lib_ignored,\"libraryExists\":$lib_exists,\"libraryBytes\":$lib_bytes,\"editorOpen\":$ed_open,\"cacheServer\":{\"mode\":$cache_mode,\"endpoint\":$cache_endpoint,\"reachable\":$cache_reachable},\"manifestRisks\":$(json_str_array ${risks[@]+"${risks[@]}"})}"
done <<EOF
$rels
EOF

free_disk=$(df -k "$REPO" | awk 'NR==2 {print $4 * 1024}')
if [ "$max_lib" -gt 0 ] && [ "${free_disk:-0}" -lt $((max_lib * 2)) ]; then
    warnings+=('free disk is less than 2x the Library size - each seeded worktree costs one Library copy')
fi

wt_json=''
while IFS= read -r wt; do
    [ -z "$wt" ] && continue
    [ -n "$wt_json" ] && wt_json="$wt_json,"
    wt_json="$wt_json\"$(json_escape "$wt")\""
done <<EOF
$(worktree_paths "$REPO")
EOF

db_json=null; [ -n "$default_br" ] && db_json="\"$(json_escape "$default_br")\""
result="{\"repoRoot\":\"$(json_escape "$REPO")\",\"defaultBranch\":$db_json,\"projects\":[$projects_json],\"worktrees\":[$wt_json],\"trackedSymlinks\":$symlink_count,\"freeDiskBytes\":${free_disk:-0},\"blockers\":$(json_str_array ${blockers[@]+"${blockers[@]}"}),\"warnings\":$(json_str_array ${warnings[@]+"${warnings[@]}"})}"

ec=0; [ "${#blockers[@]}" -gt 0 ] && ec=2
die_json "$ec" "$result"

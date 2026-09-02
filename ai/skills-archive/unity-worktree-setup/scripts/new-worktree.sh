#!/usr/bin/env bash
# new-worktree.sh - create a sibling worktree for a branch and seed its Library by copy.
# Prefers recycling an existing warm worktree: exits 4 with candidates unless --force-new.
# Exit: 0 created, 2 error, 4 recyclable worktree available.
set -u
. "$(cd "$(dirname "$0")" && pwd)/_lib.sh"

BRANCH=''; BASE_REF=''; WT_PATH=''; REPO=''; PROJECT_REL=''; FORCE_NEW=0; NO_SEED=0; MIN_DONOR_MB=200
while [ $# -gt 0 ]; do
    case $1 in
        --branch) BRANCH=$2; shift 2 ;;
        --base-ref) BASE_REF=$2; shift 2 ;;
        --path) WT_PATH=$2; shift 2 ;;
        --repo-root) REPO=$2; shift 2 ;;
        --project-rel) PROJECT_REL=$2; shift 2 ;;
        --force-new) FORCE_NEW=1; shift ;;
        --no-seed) NO_SEED=1; shift ;;
        --min-donor-mb) MIN_DONOR_MB=$2; shift 2 ;;
        *) die_json 2 "{\"error\":\"unknown flag: $(json_escape "$1")\"}" ;;
    esac
done
[ -z "$BRANCH" ] && die_json 2 '{"error":"--branch is required"}'
if [ -z "$REPO" ]; then REPO=$(repo_root || true); fi
[ -z "$REPO" ] && die_json 2 '{"error":"not inside a git repository"}'
default_br=$(default_branch "$REPO" || true)
if [ -z "$BASE_REF" ]; then
    [ -z "$default_br" ] && die_json 2 '{"error":"no --base-ref given and default branch undetectable"}'
    BASE_REF="origin/$default_br"
fi
[ -z "$PROJECT_REL" ] && PROJECT_REL=$(first_project_rel "$REPO")
[ -z "$PROJECT_REL" ] && PROJECT_REL='.'

if git -C "$REPO" show-ref --verify --quiet "refs/heads/$BRANCH" 2>/dev/null; then
    die_json 2 "{\"error\":\"branch '$(json_escape "$BRANCH")' already exists - check it out in an existing worktree instead\"}"
fi

# Warm worktrees are the asset: reuse before creating.
if [ "$FORCE_NEW" -eq 0 ]; then
    candidates=()
    first=1
    while IFS= read -r wt; do
        [ -z "$wt" ] && continue
        if [ "$first" -eq 1 ]; then first=0; continue; fi   # skip main checkout
        proj=$(project_dir_of "$wt" "$PROJECT_REL")
        [ -d "$proj/Library" ] || continue
        is_recyclable "$wt" "$PROJECT_REL" "${default_br:-}" && candidates+=("$wt")
    done <<EOF
$(worktree_paths "$REPO")
EOF
    if [ "${#candidates[@]}" -gt 0 ]; then
        die_json 4 "{\"action\":\"recycle-instead\",\"message\":\"warm recyclable worktree(s) found; run recycle-worktree.sh --path <path> --branch <branch>, or re-run with --force-new\",\"candidates\":$(json_str_array "${candidates[@]}")}"
    fi
fi

if [ -z "$WT_PATH" ]; then
    slug=$(printf '%s' "$BRANCH" | sed 's/[^A-Za-z0-9._-]/-/g')
    WT_PATH="$(dirname "$REPO")/$(basename "$REPO")-wt-$slug"
fi
[ -e "$WT_PATH" ] && die_json 2 "{\"error\":\"target path already exists: $(json_escape "$WT_PATH")\"}"

git -C "$REPO" fetch --prune >/dev/null 2>&1 || true
if ! git -C "$REPO" worktree add --detach "$WT_PATH" "$BASE_REF" >/dev/null 2>&1; then
    die_json 2 "{\"error\":\"git worktree add failed (base ref '$(json_escape "$BASE_REF")')\"}"
fi
if ! git -C "$WT_PATH" switch -c "$BRANCH" >/dev/null 2>&1; then
    die_json 2 "{\"error\":\"worktree created at $(json_escape "$WT_PATH") but 'git switch -c $(json_escape "$BRANCH")' failed\"}"
fi
[ -f "$WT_PATH/.gitmodules" ] && git -C "$WT_PATH" submodule update --init --recursive >/dev/null 2>&1

# Seed Library from the leanest warm donor so first editor open imports only the delta.
dest_proj=$(project_dir_of "$WT_PATH" "$PROJECT_REL")
seed_json=null
seeded=0
if [ "$NO_SEED" -eq 0 ]; then
    donor=$(select_donor "$REPO" "$PROJECT_REL" "$MIN_DONOR_MB" "$(norm_path "$WT_PATH")")
    if [ -n "$donor" ]; then
        donor_lib=${donor%%|*}
        rest=${donor#*|}; donor_bytes=${rest%%|*}
        start=$SECONDS
        if copy_library "$donor_lib" "$dest_proj/Library"; then
            seed_json="{\"donor\":\"$(json_escape "$donor_lib")\",\"bytes\":$donor_bytes,\"seconds\":$((SECONDS - start))}"
            seeded=1
        else
            die_json 2 "{\"error\":\"Library copy failed from $(json_escape "$donor_lib")\"}"
        fi
    fi
fi

next=()
if [ "$seeded" -eq 1 ]; then
    next+=('open the worktree in Unity once to validate the seeded Library (delta import only)')
else
    # no donor: a reachable Accelerator is the next-best way to avoid a cold local import
    acc=$(accelerator_candidate "$dest_proj" 3)
    if [ -n "$acc" ]; then
        a_ep=${acc%%|*}; rest=${acc#*|}; a_src=${rest%%|*}; rest=${rest#*|}; a_mode=${rest%%|*}; a_reach=${rest##*|}
        if [ "$a_reach" = true ]; then
            next+=("no warm donor Library found, but an Accelerator is reachable at $a_ep ($a_src config, mode=${a_mode:-unset}) - first open will pull cached artifacts (Shader Graph/VFX Graph/Burst still build locally)")
            next+=("to force it for one launch: Unity -projectPath \"$dest_proj\" -EnableCacheServer -cacheServerEndpoint $a_ep")
        else
            next+=("no warm donor Library found and the configured Accelerator $a_ep ($a_src config) is unreachable - first Unity open will be a full local import")
        fi
    else
        next+=('no warm donor Library found and no Accelerator configured - first Unity open will be a full import (consider a localhost Accelerator)')
    fi
fi

die_json 0 "{\"action\":\"created\",\"path\":\"$(json_escape "$WT_PATH")\",\"branch\":\"$(json_escape "$BRANCH")\",\"baseRef\":\"$(json_escape "$BASE_REF")\",\"seeded\":$seed_json,\"nextSteps\":$(json_str_array "${next[@]}")}"

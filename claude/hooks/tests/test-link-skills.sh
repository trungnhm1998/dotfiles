#!/usr/bin/env bash
. "$(dirname "$0")/_harness.sh"
. "$(dirname "$0")/../../../scripts/lib/link-skills.sh"

# Fixture: a fake repo skills dir with two skills, and a dst that starts as a legacy
# whole-dir symlink pointing at the repo (the pre-migration state on a real machine).
repo="$(mktemp -d)"; home="$(mktemp -d)"
mkdir -p "$repo/alpha" "$repo/beta"
echo "alpha" > "$repo/alpha/SKILL.md"
echo "beta"  > "$repo/beta/SKILL.md"
mkdir -p "$home/.claude"
dst="$home/.claude/skills"
ln -s "$repo" "$dst"                       # legacy whole-dir symlink

out=$(link_skills "$repo" "$dst"); rc=$?
assert_exit "$rc" "0" "link_skills exits 0"

# 1. Migration: dst is now a real directory, not a symlink
test -d "$dst" && test ! -L "$dst"; assert_exit "$?" "0" "dst migrated to real directory"

# 2. Safety: the source repo survived the rm (still has both skills)
test -f "$repo/alpha/SKILL.md" && test -f "$repo/beta/SKILL.md"
assert_exit "$?" "0" "repo contents intact after migration"

# 3. Per-item links: each repo skill is an individual symlink back to its source
test -L "$dst/alpha" && [ "$(readlink "$dst/alpha")" = "$repo/alpha" ]
assert_exit "$?" "0" "alpha is a per-item symlink to repo"
test -L "$dst/beta" && [ "$(readlink "$dst/beta")" = "$repo/beta" ]
assert_exit "$?" "0" "beta is a per-item symlink to repo"

# 4. Public skill (real dir) survives a re-run untouched
mkdir -p "$dst/public-skill"; echo "sentinel" > "$dst/public-skill/SKILL.md"
link_skills "$repo" "$dst" >/dev/null
test -d "$dst/public-skill" && test ! -L "$dst/public-skill"
assert_exit "$?" "0" "public real-dir skill untouched"
assert_eq "$(cat "$dst/public-skill/SKILL.md")" "sentinel" "public skill content preserved"

# 5. Name collision: a repo skill named like an existing public dir must not clobber it
mkdir -p "$repo/gamma"; echo "repo-gamma"   > "$repo/gamma/SKILL.md"
mkdir -p "$dst/gamma";  echo "public-gamma" > "$dst/gamma/SKILL.md"
link_skills "$repo" "$dst" >/dev/null
assert_eq "$(cat "$dst/gamma/SKILL.md")" "public-gamma" "name collision leaves public skill in place"
test ! -L "$dst/gamma"; assert_exit "$?" "0" "colliding name not converted to repo symlink"

# 6. Idempotency: a clean re-run changes nothing and still succeeds
link_skills "$repo" "$dst"; assert_exit "$?" "0" "idempotent re-run exits 0"
test -L "$dst/alpha" && [ "$(readlink "$dst/alpha")" = "$repo/alpha" ]
assert_exit "$?" "0" "alpha still correctly linked after re-run"

finish

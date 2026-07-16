#!/usr/bin/env bash
# shellcheck disable=SC2319  # deliberate assert idiom: [ cond ]; check $?
# Smoke test for scripts/worktree-seed.sh. Builds a throwaway git repo whose
# manifest exercises every rule (dir entry, file entry, symlink dereference,
# recursion-guard decoy, absolute-path + ".." rejection), adds worktrees, runs
# the seeder, and asserts the outcomes. Every seeder call sets ORCA_ROOT_PATH so
# root resolution ignores the ambient dotfiles repo.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
seed="$here/../worktree-seed.sh"
fail=0

ok()   { printf 'ok   - %s\n' "$1"; }
bad()  { printf 'FAIL - %s\n' "$1"; fail=1; }
check() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2"; fi; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/wtseed.XXXXXX")"
# shellcheck disable=SC2329  # invoked via trap EXIT
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

# --- Repo with a manifest exercising every rule ---
root="$tmp/repo"
mkdir -p "$root"
git -C "$root" init -q
git -C "$root" config user.email t@example.com
git -C "$root" config user.name test
printf 'tracked\n' > "$root/README.md"
git -C "$root" add README.md
git -C "$root" commit -qm init

mkdir -p "$root/.claude/skills"
printf 'skill\n'    > "$root/.claude/skills/foo.md"
printf 'settings\n' > "$root/.claude/settings.local.json"
printf 'agents\n'   > "$root/AGENTS.local.md"

# symlink entry: real symlink if the platform allows (git-bash on Windows without
# Developer Mode cannot), else a plain copy. Only assert dereference for a real one.
have_symlink=0
if ln -s AGENTS.local.md "$root/CLAUDE.local.md" 2>/dev/null; then
  have_symlink=1
else
  cp "$root/AGENTS.local.md" "$root/CLAUDE.local.md"
fi

# recursion-guard decoy: must NEVER be copied even though it is listed
mkdir -p "$root/.claude/worktrees/junk"
printf 'do-not-copy\n' > "$root/.claude/worktrees/junk/x"

cat > "$root/.worktreeinclude" <<'EOF'
# personal locals
.claude/skills
.claude/settings.local.json
AGENTS.local.md
CLAUDE.local.md
.claude/worktrees
/etc/passwd
../escape
EOF

# --- First seed into wt1 ---
wt1="$tmp/wt1"
git -C "$root" worktree add -q "$wt1" -b feat1 >/dev/null 2>&1
out="$(ORCA_ROOT_PATH="$root" bash "$seed" "$wt1" 2>&1)"; rc=$?

check "$rc" "exit 0 on normal seed"
[ -f "$wt1/.claude/skills/foo.md" ]; check $? "dir entry copied recursively"
[ -f "$wt1/.claude/settings.local.json" ]; check $? "file entry copied"
[ -f "$wt1/AGENTS.local.md" ]; check $? "symlink target file copied"
[ -f "$wt1/CLAUDE.local.md" ]; check $? "symlink entry copied"
if [ "$have_symlink" -eq 1 ]; then
  { [ -f "$wt1/CLAUDE.local.md" ] && [ ! -L "$wt1/CLAUDE.local.md" ]; }
  check $? "symlink dereferenced to a real file (cp -RL)"
else
  ok "symlink dereference skipped (platform has no real symlink)"
fi
[ ! -e "$wt1/.claude/worktrees" ]; check $? "recursion-guard decoy NOT copied"
printf '%s' "$out" | grep -q "skip absolute"; check $? "absolute path rejected with warning"
printf '%s' "$out" | grep -q "skip path with"; check $? ".. path rejected with warning"
printf '%s' "$out" | grep -q "seeded .* items ->"; check $? "summary line printed"

# --- Second run is idempotent ---
ORCA_ROOT_PATH="$root" bash "$seed" "$wt1" >/dev/null 2>&1; rc2=$?
check "$rc2" "second run exits 0 (idempotent)"
[ -f "$wt1/.claude/skills/foo.md" ]; check $? "files still present after re-seed"

# --- --all reaches a second worktree ---
wt2="$tmp/wt2"
git -C "$root" worktree add -q "$wt2" -b feat2 >/dev/null 2>&1
ORCA_ROOT_PATH="$root" bash "$seed" --all >/dev/null 2>&1
[ -f "$wt2/AGENTS.local.md" ]; check $? "--all seeds a second worktree"
[ -f "$wt1/AGENTS.local.md" ]; check $? "--all re-pushes to the first worktree too"

# --- Missing manifest: silent exit 0 ---
root2="$tmp/repo2"
mkdir -p "$root2"
git -C "$root2" init -q
git -C "$root2" config user.email t@example.com
git -C "$root2" config user.name test
printf 'x\n' > "$root2/README.md"
git -C "$root2" add README.md
git -C "$root2" commit -qm init
wt3="$tmp/wt3"
git -C "$root2" worktree add -q "$wt3" -b feat3 >/dev/null 2>&1
out3="$(ORCA_ROOT_PATH="$root2" bash "$seed" "$wt3" 2>&1)"; rc3=$?
check "$rc3" "missing manifest exits 0"
[ -z "$out3" ]; check $? "missing manifest is silent (non-tty)"

echo "----"
if [ "$fail" -eq 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit "$fail"

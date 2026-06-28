#!/usr/bin/env bash
# link_skills <src_dir> <dst_dir>
# Make <dst_dir> a REAL directory and symlink each skill subdir of <src_dir> into it by
# name — but only when that name is free, so a public (`npx skills`) or Claude Code plugin
# skill already present is never clobbered. Mirrors the per-item loop in deploy_windows.ps1.
# Side-effect-free to source (only defines a function); idempotent to re-run.
link_skills() {
	local src_dir="$1" dst_dir="$2"
	[ -d "$src_dir" ] || return 0

	# Migrate a legacy whole-dir symlink (dst_dir -> repo) to a real directory.
	# Remove ONLY the symlink itself (rm, never rm -r) so the repo is never touched.
	if [ -L "$dst_dir" ]; then
		echo "Migrating $dst_dir: whole-dir symlink -> real directory"
		rm "$dst_dir"
	fi
	mkdir -p "$dst_dir"

	local skill name target
	for skill in "$src_dir"/*/; do
		[ -d "$skill" ] || continue          # unmatched glob or non-dir -> skip
		name="$(basename "$skill")"
		target="$dst_dir/$name"
		if [ -e "$target" ]; then
			:                                # live dir/symlink (repo/public/plugin) -> leave it
		else
			[ -L "$target" ] && rm "$target" # clear a dangling symlink before relinking
			ln -s "${skill%/}" "$target"
			echo "Linked skill: $name"
		fi
	done
}

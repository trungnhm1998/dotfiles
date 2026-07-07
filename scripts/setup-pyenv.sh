#!/usr/bin/env bash
# setup-pyenv.sh — install pyenv + Python 3 (cross-platform, idempotent).
# Called by deploy.sh (Linux/WSL2) and setup_mac.sh (macOS); safe to re-run.
#
# Python 2.7 is deliberately NOT handled here: it's EOL and needs OpenSSL 1.1
# built from source on both current macOS and Ubuntu 24.04, which is too slow
# and fragile for an every-machine deploy. Run scripts/setup-python2.sh on the
# machines that actually need it (opt-in).
set -euo pipefail

PY3_SERIES="3.13" # newest 3.13.x is resolved from `pyenv install --list`
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

log() { printf '\n[setup-pyenv] %s\n' "$1"; }

# 1. Ensure the pyenv binary exists and is usable in this shell.
ensure_pyenv() {
	if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
		export PATH="$PYENV_ROOT/bin:$PATH"
	elif command -v pyenv >/dev/null 2>&1; then
		: # already on PATH (e.g. Homebrew-installed pyenv on macOS)
	else
		log "installing pyenv via pyenv.run"
		curl -fsSL https://pyenv.run | bash
		export PATH="$PYENV_ROOT/bin:$PATH"
	fi
	command -v pyenv >/dev/null 2>&1 || {
		echo "[setup-pyenv] ERROR: pyenv not available after install" >&2
		exit 1
	}
	eval "$(pyenv init - bash)"
}

# 2. Install CPython build dependencies (per-OS; idempotent).
install_build_deps() {
	case "$(uname -s)" in
	Linux)
		if command -v apt-get >/dev/null 2>&1; then
			local pkgs=(make build-essential libssl-dev zlib1g-dev libbz2-dev
				libreadline-dev libsqlite3-dev libncurses-dev xz-utils
				tk-dev libffi-dev liblzma-dev)
			local missing=()
			local p
			for p in "${pkgs[@]}"; do
				dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
			done
			if [ "${#missing[@]}" -eq 0 ]; then
				log "CPython build deps already present — skipping apt"
			else
				log "installing missing build deps via apt: ${missing[*]}"
				sudo apt-get update -qq
				sudo apt-get install -y --no-install-recommends "${missing[@]}"
			fi
		else
			log "non-apt Linux: install CPython build deps yourself (see pyenv wiki 'Suggested build environment')"
		fi
		;;
	Darwin)
		if command -v brew >/dev/null 2>&1; then
			log "installing CPython build deps via brew"
			brew install openssl readline sqlite3 xz zlib tcl-tk || true
		fi
		;;
	esac
}

# `pyenv global` for py3 while preserving any already-installed 2.7.x, so this
# script and setup-python2.sh can run in either order without dropping a runtime.
set_global() {
	local py3="$1" py2
	py2="$(pyenv versions --bare 2>/dev/null | grep -E '^2\.7\.' | tail -1)" || true
	if [ -n "$py2" ]; then
		pyenv global "$py3" "$py2"
	else
		pyenv global "$py3"
	fi
	log "pyenv global -> $(pyenv global | tr '\n' ' ')"
}

# 3. Install the newest Python 3.13.x and make it the default.
install_python3() {
	local latest
	latest="$(pyenv install --list | tr -d ' ' | grep -E "^${PY3_SERIES}\.[0-9]+$" | tail -1)" || true
	[ -n "$latest" ] || latest="$PY3_SERIES"
	log "installing Python $latest (compiles; a few minutes if not cached)"
	pyenv install -s "$latest"
	set_global "$latest"
}

ensure_pyenv
install_build_deps
install_python3
log "done. python -> $(python --version 2>&1)"

#!/usr/bin/env bash
# setup-python2.sh — OPT-IN: install a functional Python 2.7.18 (working ssl + pip).
#
# Python 2.7's ssl module needs OpenSSL 1.1. How we supply it differs by OS:
#   - Linux: OpenSSL 1.1 is gone from the distro AND pyenv does not bundle it on
#     Linux, so we compile 1.1.1w from source and point 2.7's setup.py at it.
#   - macOS: pyenv's own 2.7.18 build definition already bundles openssl-1.1.1v
#     (has_broken_mac_openssl) + readline-8.0, and a hand-built OpenSSL would be
#     ignored — so we let pyenv handle it and only relax one clang error.
# pip is auto-pinned to 20.3.4 (the py2 ceiling) by pyenv's ensurepip_lt21.
#
# EOL + slow on purpose — NOT wired into deploy.sh / setup_mac.sh. Run only where
# you need py2:   bash scripts/setup-python2.sh
#
# Prereq: pyenv must exist (run scripts/setup-pyenv.sh first).
set -euo pipefail

PY2_VERSION="2.7.18"
OPENSSL_VERSION="1.1.1w"
OPENSSL_PREFIX="$HOME/.local/openssl-1.1"
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

log() { printf '\n[setup-python2] %s\n' "$1"; }

need_pyenv() {
	[ -x "$PYENV_ROOT/bin/pyenv" ] && export PATH="$PYENV_ROOT/bin:$PATH"
	command -v pyenv >/dev/null 2>&1 || {
		echo "[setup-python2] ERROR: pyenv not found — run scripts/setup-pyenv.sh first." >&2
		exit 1
	}
	# Recent build defs matter: they carry the macOS bundled-openssl-1.1.1v branch
	# and the ensurepip pip-20.3.4 pin for 2.7.18. Best-effort; ignore no-network.
	pyenv update >/dev/null 2>&1 || true
	eval "$(pyenv init - bash)"
}

# Linux only: compile OpenSSL 1.1.1 into a private prefix (macOS pyenv bundles its own).
build_openssl_11_linux() {
	if [ -x "$OPENSSL_PREFIX/bin/openssl" ]; then
		log "OpenSSL 1.1 already present at $OPENSSL_PREFIX"
		return
	fi
	log "building OpenSSL $OPENSSL_VERSION -> $OPENSSL_PREFIX (a few minutes)"
	local tmp tag
	tmp="$(mktemp -d)"
	tag="OpenSSL_${OPENSSL_VERSION//./_}" # 1.1.1w -> OpenSSL_1_1_1w
	curl -fsSL "https://github.com/openssl/openssl/releases/download/${tag}/openssl-${OPENSSL_VERSION}.tar.gz" -o "$tmp/openssl.tar.gz"
	tar xf "$tmp/openssl.tar.gz" -C "$tmp"
	(
		cd "$tmp/openssl-${OPENSSL_VERSION}"
		./config --prefix="$OPENSSL_PREFIX" --openssldir="$OPENSSL_PREFIX" shared zlib
		make -j"$(getconf _NPROCESSORS_ONLN)"
		make install_sw # libraries + headers only; skip man pages
	)
	rm -rf "$tmp"
}

install_python2() {
	if pyenv versions --bare 2>/dev/null | grep -qx "$PY2_VERSION"; then
		log "Python $PY2_VERSION already installed — skipping build"
	elif [ "$(uname -s)" = "Darwin" ]; then
		# pyenv bundles openssl-1.1.1v + readline-8.0; just relax clang's implicit-decl hard error.
		log "installing Python $PY2_VERSION (pyenv-bundled OpenSSL 1.1 on macOS)"
		CFLAGS="-Wno-error=implicit-function-declaration" pyenv install -s "$PY2_VERSION"
	else
		# Linux: 2.7's setup.py finds ssl via CPPFLAGS/LDFLAGS (2.7 has no --with-openssl).
		# rpath bakes the lib path -> no runtime LD_LIBRARY_PATH. -fcommon: 2.7.18 predates
		# GCC 10's -fno-common default, else duplicate-symbol link errors.
		log "installing Python $PY2_VERSION against $OPENSSL_PREFIX (compiles; a few minutes)"
		CPPFLAGS="-I$OPENSSL_PREFIX/include" \
			LDFLAGS="-L$OPENSSL_PREFIX/lib -Wl,-rpath,$OPENSSL_PREFIX/lib" \
			CFLAGS="-O2 -fcommon" \
			pyenv install -s "$PY2_VERSION"
	fi
	# Keep py3 as the default `python`; add py2 to the global set so `python2` resolves.
	local py3
	py3="$(pyenv versions --bare 2>/dev/null | grep -E '^3\.' | tail -1)" || true
	if [ -n "$py3" ]; then
		pyenv global "$py3" "$PY2_VERSION"
	else
		pyenv global "$PY2_VERSION"
	fi
	log "pyenv global -> $(pyenv global | tr '\n' ' ')"
}

verify() {
	local py2bin="$PYENV_ROOT/versions/$PY2_VERSION/bin/python2"
	log "verifying ssl links against OpenSSL 1.1"
	"$py2bin" -c 'import ssl; print("  ssl OK:", ssl.OPENSSL_VERSION)'
	"$py2bin" -m pip --version
	log "python2 ready: $("$py2bin" --version 2>&1)"
}

need_pyenv
[ "$(uname -s)" = "Darwin" ] || build_openssl_11_linux
install_python2
verify
log "done. Use 'python2' (global shim) or 'pyenv shell $PY2_VERSION'."

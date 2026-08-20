#!/usr/bin/env bash
# Update the dev tools this dotfiles setup depends on, plus the plugin managers.
#
# apt/Ubuntu pins these years behind upstream (ripgrep 14 vs 15, eza 0.18 vs 0.23,
# btop 1.3 vs 1.4...), so on Linux we pull the official static musl release binaries
# straight from GitHub. They land in ~/.local/bin, which sits ahead of /usr/bin and
# /usr/local/bin in PATH, so no sudo and no fighting dpkg. macOS defers to brew.
#
# Idempotent: anything already at the latest tag is skipped.
#   ./update-tools.sh            update everything
#   ./update-tools.sh --check    report what is stale, change nothing
#   ./update-tools.sh --bins     binaries only, skip plugin managers
#   ./update-tools.sh --plugins  plugin managers only, skip binaries
set -uo pipefail

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DO_BINS=true
DO_PLUGINS=true
CHECK_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --bins) DO_PLUGINS=false ;;
    --plugins) DO_BINS=false ;;
    -h | --help) sed -n '2,13p' "$0" | sed 's/^# \?//' && exit 0 ;;
    *) echo "unknown flag: $arg" >&2 && exit 2 ;;
  esac
done

STALE=0
FAILED=0

# name[:probe]|repo|asset template|binaries to pull out of it
# :probe overrides which binary is asked for --version (yazi's own --version opens
# the TUI and hangs on a non-tty stdin; its 'ya' sidecar answers properly).
# {VER} = tag without a leading v, {TAG} = tag verbatim,
# {ARCH} = x86_64/aarch64, {ARCH_ALT} = x86_64/arm64, {ARCH_DEB} = amd64/arm64
TOOLS="
rg|BurntSushi/ripgrep|ripgrep-{VER}-{ARCH}-unknown-linux-musl.tar.gz|rg
fd|sharkdp/fd|fd-{TAG}-{ARCH}-unknown-linux-musl.tar.gz|fd
bat|sharkdp/bat|bat-{TAG}-{ARCH}-unknown-linux-musl.tar.gz|bat
eza|eza-community/eza|eza_{ARCH}-unknown-linux-musl.tar.gz|eza
zoxide|ajeetdsouza/zoxide|zoxide-{VER}-{ARCH}-unknown-linux-musl.tar.gz|zoxide
yazi:ya|sxyazi/yazi|yazi-{ARCH}-unknown-linux-musl.zip|yazi ya
lazygit|jesseduffield/lazygit|lazygit_{VER}_linux_{ARCH_ALT}.tar.gz|lazygit
starship|starship/starship|starship-{ARCH}-unknown-linux-musl.tar.gz|starship
btop|aristocratos/btop|btop-{ARCH}-unknown-linux-musl.tar.gz|btop
jq|jqlang/jq|jq-linux-{ARCH_DEB}|jq
gh|cli/cli|gh_{VER}_linux_{ARCH_DEB}.tar.gz|gh
"

# Same set as TOOLS above, under their Homebrew formula names.
BREW_FORMULAE="ripgrep fd bat eza zoxide yazi lazygit starship btop jq gh fzf neovim"

case "$(uname -m)" in
  x86_64 | amd64) ARCH=x86_64 ARCH_ALT=x86_64 ARCH_DEB=amd64 ;;
  aarch64 | arm64) ARCH=aarch64 ARCH_ALT=arm64 ARCH_DEB=arm64 ;;
  *) echo "unsupported arch $(uname -m); skipping binaries" >&2 && DO_BINS=false ;;
esac

# Resolve the newest tag without burning GitHub API quota: /releases/latest 302s
# to /releases/tag/<tag>, and a HEAD request is enough to read the Location.
latest_tag() {
  curl -fsSI --max-time 20 "https://github.com/$1/releases/latest" \
    | tr -d '\r' | awk 'tolower($1) == "location:" { n = split($2, a, "/"); print a[n] }'
}

# Version formats vary wildly (lazygit buries it in "version=0.64.1"), so just look
# for the tag as a whole token anywhere in --version output.
is_current() {
  local out
  command -v "$1" > /dev/null 2>&1 || return 1
  # Capture first, then match. Piping the probe straight into `grep -q` lets grep
  # exit on the first hit, SIGPIPE the probe mid-write, and pipefail then reports
  # the whole pipeline as failed -- which made btop look perpetually out of date.
  out="$(timeout 5 "$1" --version < /dev/null 2>&1)" || true
  grep -qE "(^|[^0-9.])${2//./\\.}([^0-9.]|$)" <<< "$out"
}

install_release() {
  local name="$1" repo="$2" asset="$3" bins="$4" probe tag ver url tmp src first
  probe="${name#*:}"
  name="${name%%:*}"
  tag="$(latest_tag "$repo")"
  if [ -z "$tag" ]; then
    printf '  %-9s ! could not resolve latest tag\n' "$name"
    FAILED=$((FAILED + 1))
    return 1
  fi
  ver="$(printf '%s' "$tag" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"

  if is_current "$probe" "$ver"; then
    printf '  %-9s %s (current)\n' "$name" "$ver"
    return 0
  fi

  STALE=$((STALE + 1))
  if [ "$CHECK_ONLY" = true ]; then
    printf '  %-9s %s -> %s STALE\n' "$name" "$(installed_version "$probe")" "$ver"
    return 0
  fi
  printf '  %-9s %s -> %s updating...\n' "$name" "$(installed_version "$probe")" "$ver"

  asset="${asset//\{VER\}/$ver}"
  asset="${asset//\{TAG\}/$tag}"
  asset="${asset//\{ARCH_ALT\}/$ARCH_ALT}"
  asset="${asset//\{ARCH_DEB\}/$ARCH_DEB}"
  asset="${asset//\{ARCH\}/$ARCH}"
  url="https://github.com/$repo/releases/download/$tag/$asset"

  tmp="$(mktemp -d)"
  if ! curl -fsSL --max-time 180 -o "$tmp/$asset" "$url"; then
    printf '  %-9s ! download failed: %s\n' "$name" "$url"
    rm -rf "$tmp"
    FAILED=$((FAILED + 1))
    return 1
  fi

  first="${bins%% *}"
  case "$asset" in
    *.tar.gz | *.tgz) tar -xzf "$tmp/$asset" -C "$tmp" ;;
    *.zip) unzip -qo "$tmp/$asset" -d "$tmp" ;;
    *) mv "$tmp/$asset" "$tmp/$first" ;; # bare binary, no archive
  esac

  for b in $bins; do
    src="$(find "$tmp" -type f -name "$b" -print -quit)"
    if [ -z "$src" ]; then
      printf '  %-9s ! %s not found inside %s\n' "$name" "$b" "$asset"
      FAILED=$((FAILED + 1))
      continue
    fi
    # install (not ln) so a stale symlink left by apt shims is replaced outright.
    rm -f "$BIN_DIR/$b"
    install -Dm755 "$src" "$BIN_DIR/$b"
  done
  rm -rf "$tmp"
}

installed_version() {
  local out
  command -v "$1" > /dev/null 2>&1 || {
    echo "absent"
    return
  }
  out="$(timeout 5 "$1" --version < /dev/null 2>&1)" || true
  grep -m1 -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<< "$out"
}

update_binaries() {
  if [ "$(uname -s)" = "Darwin" ]; then
    # Homebrew keeps these current on macOS. Scoped to our formulae on purpose:
    # a bare `brew upgrade` would churn every unrelated package on the machine.
    echo "==> Homebrew"
    local formulae
    read -ra formulae <<< "$BREW_FORMULAE"
    if [ "$CHECK_ONLY" = true ]; then
      brew outdated "${formulae[@]}"
      return 0
    fi
    brew update && brew upgrade "${formulae[@]}"
    return 0
  fi

  echo "==> Release binaries -> $BIN_DIR"
  mkdir -p "$BIN_DIR"
  # fd 3, not stdin: a piped while loses STALE/FAILED to a subshell, and tools that
  # read stdin on --version (yazi) would otherwise eat rows out of the table.
  while IFS='|' read -r name repo asset bins <&3; do
    [ -n "$name" ] || continue
    install_release "$name" "$repo" "$asset" "$bins"
  done 3<<< "$TOOLS"
}

# git-managed things that ship their own updater
update_plugins() {
  echo "==> fzf"
  if [ -d "$HOME/.fzf/.git" ]; then
    git -C "$HOME/.fzf" fetch -q --depth 1 origin master \
      && git -C "$HOME/.fzf" reset -q --hard FETCH_HEAD \
      && "$HOME/.fzf/install" --bin > /dev/null 2>&1 && echo "  fzf $("$HOME"/.fzf/bin/fzf --version)"
  else
    echo "  skipped (no ~/.fzf checkout)"
  fi

  echo "==> zsh plugins + oh-my-zsh"
  for repo in "$HOME/.oh-my-zsh" "$HOME"/.oh-my-zsh/custom/plugins/*/ "$HOME"/.oh-my-zsh/custom/themes/*/; do
    [ -d "$repo/.git" ] || continue
    printf '  %-24s %s\n' "$(basename "$repo")" \
      "$(git -C "$repo" pull -q --ff-only > /dev/null 2>&1 && echo ok || echo 'skipped (local changes or diverged)')"
  done

  echo "==> tmux plugins"
  for repo in "$HOME"/.tmux/plugins/*/; do
    [ -d "$repo/.git" ] || continue
    printf '  %-24s %s\n' "$(basename "$repo")" \
      "$(git -C "$repo" pull -q --ff-only > /dev/null 2>&1 && echo ok || echo 'skipped (local changes or diverged)')"
  done
  # ~/.config/tmux/plugins/catppuccin is deliberately pinned to a tag by deploy.sh; leave it.

  echo "==> Neovim plugins (lazy.nvim)"
  if command -v nvim > /dev/null 2>&1; then
    nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3
    nvim --headless "+Lazy! load mason.nvim" "+MasonUpdate" +qa 2>&1 | tail -1
  else
    echo "  skipped (nvim not installed)"
  fi
}

if [ "$CHECK_ONLY" = true ]; then
  echo "Checking for updates (no changes will be made)"
fi
[ "$DO_BINS" = true ] && update_binaries
[ "$DO_PLUGINS" = true ] && [ "$CHECK_ONLY" = false ] && update_plugins

# bat refuses to run at all when its cached themes were built by another version.
if [ "$DO_BINS" = true ] && [ "$CHECK_ONLY" = false ] && command -v bat > /dev/null 2>&1; then
  if [ -d "$(bat --config-dir 2>/dev/null)/themes" ]; then
    echo "==> bat theme cache"
    bat cache --build > /dev/null 2>&1 && echo "  rebuilt" || echo "  ! rebuild failed"
  fi
fi

echo
if [ "$CHECK_ONLY" = true ]; then
  echo "$STALE tool(s) out of date. Run without --check to update."
else
  echo "Done. $FAILED failure(s)."
  echo "Open a new shell (or 'hash -r') so PATH picks up the refreshed binaries."
fi
[ "$FAILED" -eq 0 ]

#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path-to-lua-file>" >&2
  exit 1
fi

stylua_cmd=""

if [ -x "$(command -v stylua 2>/dev/null)" ]; then
  stylua_cmd="$(command -v stylua)"
elif [ -x "$HOME/.local/share/nvim/mason/bin/stylua" ]; then
  stylua_cmd="$HOME/.local/share/nvim/mason/bin/stylua"
else
  echo "stylua is not installed or not on PATH (and Mason stylua was not found)" >&2
  exit 1
fi

target_file="$1"

if ! [ -f "$target_file" ]; then
  echo "File not found: $target_file" >&2
  exit 1
fi

case "$target_file" in
  *.lua) ;;
  *)
    echo "Expected a .lua file: $target_file" >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_path="$script_dir/.config/nvim/stylua.toml"

if ! [ -f "$config_path" ]; then
  echo "Could not find stylua config at: $config_path" >&2
  exit 1
fi

"$stylua_cmd" --config-path "$config_path" "$target_file"

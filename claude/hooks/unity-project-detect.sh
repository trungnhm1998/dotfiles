#!/bin/bash
# SessionStart hook: if cwd is a Unity project, emit a one-line context note. Silent otherwise.
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
ver_file="$dir/ProjectSettings/ProjectVersion.txt"
[ -f "$ver_file" ] || exit 0   # not a Unity project -> say nothing

unity_ver=$(grep -m1 '^m_EditorVersion:' "$ver_file" 2>/dev/null | awk '{print $2}')
[ -n "$unity_ver" ] || unity_ver="unknown"

pipeline="Built-in"
manifest="$dir/Packages/manifest.json"
if [ -f "$manifest" ]; then
  if grep -q 'com.unity.render-pipelines.universal' "$manifest" 2>/dev/null; then
    pipeline="URP"
  elif grep -q 'com.unity.render-pipelines.high-definition' "$manifest" 2>/dev/null; then
    pipeline="HDRP"
  fi
fi

echo "Unity project detected: version ${unity_ver}, render pipeline ${pipeline}. Use the Unity MCP bridge to inspect the live Editor; verify APIs via context7."
exit 0

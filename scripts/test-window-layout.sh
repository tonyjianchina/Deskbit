#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/desktop-sticky-layout.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/DesktopSticky/NoteWindowLayout.swift" \
  "$project_dir/Tests/WindowLayoutProbe.swift" \
  -o "$probe_binary"

"$probe_binary"

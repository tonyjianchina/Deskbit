#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/desktop-sticky-focus.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/DesktopSticky/NoteAppearance.swift" \
  "$project_dir/Sources/DesktopSticky/StickyWindow.swift" \
  "$project_dir/Tests/FocusProbe.swift" \
  -o "$probe_binary"

"$probe_binary"

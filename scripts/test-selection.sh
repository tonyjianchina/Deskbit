#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-selection.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Deskbit/NoteSelection.swift" \
  "$project_dir/Tests/SelectionProbe.swift" \
  -o "$probe_binary"

"$probe_binary"

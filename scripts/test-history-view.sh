#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-history-view.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Deskbit/NoteAppearance.swift" \
  "$project_dir/Sources/Deskbit/Models.swift" \
  "$project_dir/Sources/Deskbit/HistoryViews.swift" \
  "$project_dir/Tests/HistoryViewProbe.swift" \
  -o "$probe_binary"

"$probe_binary" "$@"

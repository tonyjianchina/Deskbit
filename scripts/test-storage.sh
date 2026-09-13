#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-storage.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Deskbit/NoteAppearance.swift" \
  "$project_dir/Sources/Deskbit/Models.swift" \
  "$project_dir/Sources/Deskbit/NoteStore.swift" \
  "$project_dir/Tests/StorageProbe.swift" \
  -o "$probe_binary"

"$probe_binary"

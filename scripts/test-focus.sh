#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-focus.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  ${(f)"$(find "$project_dir/Sources/Deskbit" -maxdepth 1 -name '*.swift' ! -name 'main.swift' -print | sort)"} \
  "$project_dir/Tests/FocusProbe.swift" \
  -o "$probe_binary"

"$probe_binary"

#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-application-menu.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Deskbit/ApplicationMenu.swift" \
  "$project_dir/Tests/ApplicationMenuProbe.swift" \
  -o "$probe_binary"

"$probe_binary"

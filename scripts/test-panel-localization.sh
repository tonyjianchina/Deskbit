#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-panel-localization.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT
sources=("$project_dir"/Sources/Deskbit/*.swift)
sources=(${sources:#*/main.swift})
swiftc "${sources[@]}" "$project_dir/Tests/PanelLocalizationProbe.swift" -o "$probe_binary"
"$probe_binary"

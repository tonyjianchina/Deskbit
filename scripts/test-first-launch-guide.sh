#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-first-launch-guide.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Deskbit/Localization.swift" \
  "$project_dir/Sources/Deskbit/FirstLaunchGuide.swift" \
  "$project_dir/Tests/FirstLaunchGuideProbe.swift" \
  -o "$probe_binary"

"$probe_binary" en -DeskbitLanguage en
"$probe_binary" zh-Hans -DeskbitLanguage zh-Hans

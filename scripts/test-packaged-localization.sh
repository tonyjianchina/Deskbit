#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="${1:-$project_dir/dist/Deskbit.app}"
resource_bundle="$app_dir/Contents/Resources/Deskbit_Deskbit.bundle"
if [[ ! -d "$resource_bundle" ]]; then
  print -u2 'Build the app with ./scripts/build-app.sh before this packaging check.'
  exit 1
fi
probe_root="$(mktemp -d /tmp/deskbit-packaged-localization.XXXXXX)"
trap 'rm -rf "$probe_root"' EXIT
contents="$probe_root/Deskbit.app/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources"
ditto "$resource_bundle" "$contents/Resources/Deskbit_Deskbit.bundle"
cat > "$contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.local.deskbit.localization-probe</string>
<key>CFBundleExecutable</key><string>Probe</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
swiftc -D SWIFT_PACKAGE \
  "$project_dir/Sources/Deskbit/Localization.swift" \
  "$project_dir/Tests/PackagedLocalizationProbe.swift" \
  -o "$contents/MacOS/Probe"
"$contents/MacOS/Probe" -DeskbitLanguage en
"$contents/MacOS/Probe" -DeskbitLanguage zh-Hans

#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/Deskbit.app"
version="${1:-${MARKETING_VERSION:-}}"

if [ -z "$version" ]; then
  echo "usage: $0 <version>" >&2
  exit 1
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "version must use numeric SemVer (X.Y.Z): $version" >&2
  exit 1
fi
if [ ! -d "$app" ]; then
  echo "Deskbit.app is missing; run scripts/build-app.sh first" >&2
  exit 1
fi
if [ ! -f "$app/Contents/Info.plist" ]; then
  echo "Deskbit.app is incomplete; run scripts/build-app.sh again" >&2
  exit 1
fi
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
if [ "$app_version" != "$version" ]; then
  echo "DMG version $version does not match Deskbit.app version $app_version" >&2
  exit 1
fi

output="$root/dist/Deskbit-v${version}-macOS-universal.dmg"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

ditto "$app" "$stage/Deskbit.app"
ln -s /Applications "$stage/Applications"

rm -f "$output"
hdiutil create \
  -volname "Deskbit" \
  -srcfolder "$stage" \
  -format UDZO \
  -ov \
  "$output" >/dev/null

hdiutil imageinfo "$output" >/dev/null
echo "$output"

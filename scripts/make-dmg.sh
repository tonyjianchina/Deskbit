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
if hdiutil info | grep -Eq $'\t/Volumes/Deskbit( [0-9]+)?$'; then
  echo "a Deskbit disk image is already mounted; eject it before packaging" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
stage="$work_dir/stage"
readwrite_image="$work_dir/Deskbit-rw.dmg"
mounted_device=""

cleanup() {
  if [ -n "$mounted_device" ]; then
    hdiutil detach "$mounted_device" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$stage/.background"
ditto "$app" "$stage/Deskbit.app"
ln -s /Applications "$stage/Applications"
ditto "$app/Contents/Resources/Deskbit.icns" "$stage/.VolumeIcon.icns"
swift "$root/Tools/GenerateDMGBackground.swift" "$stage/.background/Deskbit.png"

rm -f "$output"
hdiutil create \
  -volname "Deskbit" \
  -srcfolder "$stage" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$readwrite_image" >/dev/null

attach_output="$(hdiutil attach -readwrite -noverify -noautoopen "$readwrite_image")"
mounted_device="$(printf '%s\n' "$attach_output" | awk -F '\t' '$3 != "" { sub(/[[:space:]]+$/, "", $1); print $1; exit }')"
mount_point="$(printf '%s\n' "$attach_output" | awk -F '\t' '$3 != "" { print $3; exit }')"

if [ -z "$mounted_device" ] || [ -z "$mount_point" ] || [ ! -d "$mount_point" ]; then
  echo "failed to mount temporary DMG" >&2
  exit 1
fi

SetFile -a C "$mount_point"
SetFile -a V "$mount_point/.background" "$mount_point/.VolumeIcon.icns"

osascript - "Deskbit" <<'APPLESCRIPT'
on run argv
  set volumeName to item 1 of argv

  tell application "Finder"
    tell disk volumeName
      open
      set installerWindow to container window
      set current view of installerWindow to icon view
      set toolbar visible of installerWindow to false
      set statusbar visible of installerWindow to false
      set pathbar visible of installerWindow to false
      set bounds of installerWindow to {180, 120, 900, 630}

      set viewOptions to icon view options of installerWindow
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 112
      set text size of viewOptions to 16
      set background picture of viewOptions to file ".background:Deskbit.png"

      set position of item "Deskbit.app" of installerWindow to {170, 286}
      set position of item "Applications" of installerWindow to {550, 286}

      update without registering applications
      delay 2
      close installerWindow
      open
      delay 2
    end tell
  end tell
end run
APPLESCRIPT

sync
hdiutil detach "$mounted_device" >/dev/null
mounted_device=""

hdiutil convert "$readwrite_image" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "$output" >/dev/null

hdiutil imageinfo "$output" >/dev/null
echo "$output"

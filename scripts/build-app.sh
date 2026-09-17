#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/Deskbit.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"

if [[ "$configuration" == "release" ]]; then
  swift build -c release --arch arm64
  arm_binary="$(swift build -c release --arch arm64 --show-bin-path)/Deskbit"
  swift build -c release --arch x86_64
  intel_binary="$(swift build -c release --arch x86_64 --show-bin-path)/Deskbit"
  lipo -create "$arm_binary" "$intel_binary" -output "$contents_dir/MacOS/Deskbit"
else
  swift build -c "$configuration"
  binary_path="$(swift build -c "$configuration" --show-bin-path)/Deskbit"
  cp "$binary_path" "$contents_dir/MacOS/Deskbit"
fi

icon_work="$project_dir/.build/Deskbit.iconset"
mkdir -p "$icon_work"
swift "$project_dir/Tools/GenerateIcon.swift" "$icon_work/icon_512x512@2x.png"
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" "512 512x512"; do
  pixels="${spec%% *}"
  filename="${spec#* }"
  sips -z "$pixels" "$pixels" "$icon_work/icon_512x512@2x.png" --out "$icon_work/icon_$filename.png" >/dev/null
done
iconutil -c icns "$icon_work" -o "$contents_dir/Resources/Deskbit.icns"

plutil -create xml1 "$contents_dir/Info.plist"
plutil -insert CFBundleDisplayName -string "Deskbit" "$contents_dir/Info.plist"
plutil -insert CFBundleExecutable -string "Deskbit" "$contents_dir/Info.plist"
plutil -insert CFBundleIconFile -string "Deskbit" "$contents_dir/Info.plist"
plutil -insert CFBundleIdentifier -string "com.local.deskbit" "$contents_dir/Info.plist"
plutil -insert CFBundleInfoDictionaryVersion -string "6.0" "$contents_dir/Info.plist"
plutil -insert CFBundleName -string "Deskbit" "$contents_dir/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$contents_dir/Info.plist"
plutil -insert CFBundleShortVersionString -string "1.2.0" "$contents_dir/Info.plist"
plutil -insert CFBundleVersion -string "3" "$contents_dir/Info.plist"
plutil -insert LSMinimumSystemVersion -string "11.0" "$contents_dir/Info.plist"
plutil -insert LSArchitecturePriority -json '["arm64","x86_64"]' "$contents_dir/Info.plist"
plutil -insert LSUIElement -bool true "$contents_dir/Info.plist"
plutil -insert NSUserNotificationAlertStyle -string "alert" "$contents_dir/Info.plist"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"

#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_dir="$project_dir/dist/Deskbit.app"
contents_dir="$app_dir/Contents"
marketing_version="${MARKETING_VERSION:-1.2.2}"
build_number="${BUILD_NUMBER:-5}"
bundle_identifier="${BUNDLE_IDENTIFIER:-com.local.deskbit}"
sparkle_dir="$project_dir/Sparkle"
sparkle_framework="$sparkle_dir/Sparkle.framework"
sparkle_feed_url="${SPARKLE_FEED_URL:-https://raw.githubusercontent.com/tonyjianchina/Deskbit/main/appcast.xml}"
sparkle_public_key="${SPARKLE_PUBLIC_KEY:-}"
codesign_identity="${CODESIGN_IDENTITY:--}"

if [[ ! "$marketing_version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "MARKETING_VERSION must use numeric SemVer (X.Y.Z): $marketing_version"
  exit 1
fi
if [[ ! "$build_number" =~ '^[0-9]+$' ]]; then
  print -u2 "BUILD_NUMBER must be a positive integer: $build_number"
  exit 1
fi

cd "$project_dir"
rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"

swift_build_flags=()
has_sparkle=false
if [[ -d "$sparkle_framework" ]]; then
  has_sparkle=true
  swift_build_flags=(
    -Xswiftc -F -Xswiftc "$sparkle_dir"
    -Xlinker "-F$sparkle_dir"
    -Xlinker -framework
    -Xlinker Sparkle
    -Xlinker -rpath
    -Xlinker "@executable_path/../Frameworks"
  )
fi

if [[ "$configuration" == "release" ]]; then
  swift build -c release --arch arm64 "${swift_build_flags[@]}"
  arm_binary="$(swift build -c release --arch arm64 --show-bin-path "${swift_build_flags[@]}")/Deskbit"
  swift build -c release --arch x86_64 "${swift_build_flags[@]}"
  intel_binary="$(swift build -c release --arch x86_64 --show-bin-path "${swift_build_flags[@]}")/Deskbit"
  lipo -create "$arm_binary" "$intel_binary" -output "$contents_dir/MacOS/Deskbit"
  resource_bundle="${arm_binary:h}/Deskbit_Deskbit.bundle"
else
  swift build -c "$configuration" "${swift_build_flags[@]}"
  binary_path="$(swift build -c "$configuration" --show-bin-path "${swift_build_flags[@]}")/Deskbit"
  cp "$binary_path" "$contents_dir/MacOS/Deskbit"
  resource_bundle="${binary_path:h}/Deskbit_Deskbit.bundle"
fi

ditto "$resource_bundle" "$contents_dir/Resources/Deskbit_Deskbit.bundle"
if [[ "$has_sparkle" == true ]]; then
  mkdir -p "$contents_dir/Frameworks"
  ditto "$sparkle_framework" "$contents_dir/Frameworks/Sparkle.framework"
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
plutil -insert CFBundleIdentifier -string "$bundle_identifier" "$contents_dir/Info.plist"
plutil -insert CFBundleInfoDictionaryVersion -string "6.0" "$contents_dir/Info.plist"
plutil -insert CFBundleName -string "Deskbit" "$contents_dir/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$contents_dir/Info.plist"
plutil -insert CFBundleShortVersionString -string "$marketing_version" "$contents_dir/Info.plist"
plutil -insert CFBundleVersion -string "$build_number" "$contents_dir/Info.plist"
plutil -insert CFBundleDevelopmentRegion -string "en" "$contents_dir/Info.plist"
plutil -insert CFBundleLocalizations -json '["en","zh-Hans"]' "$contents_dir/Info.plist"
plutil -insert LSMinimumSystemVersion -string "11.0" "$contents_dir/Info.plist"
plutil -insert LSArchitecturePriority -json '["arm64","x86_64"]' "$contents_dir/Info.plist"
plutil -insert LSUIElement -bool true "$contents_dir/Info.plist"
plutil -insert NSUserNotificationAlertStyle -string "alert" "$contents_dir/Info.plist"
if [[ "$has_sparkle" == true ]]; then
  plutil -insert SUFeedURL -string "$sparkle_feed_url" "$contents_dir/Info.plist"
  plutil -insert SUEnableAutomaticChecks -bool true "$contents_dir/Info.plist"
  plutil -insert SUScheduledCheckInterval -integer 86400 "$contents_dir/Info.plist"
  if [[ -n "$sparkle_public_key" ]]; then
    plutil -insert SUPublicEDKey -string "$sparkle_public_key" "$contents_dir/Info.plist"
  fi
fi

codesign_options=(--force --sign "$codesign_identity")
if [[ "$codesign_identity" != "-" ]]; then
  codesign_options+=(--options runtime --timestamp)
fi

if [[ "$has_sparkle" == true ]]; then
  embedded_framework="$contents_dir/Frameworks/Sparkle.framework"
  while IFS= read -r nested_bundle; do
    codesign "${codesign_options[@]}" "$nested_bundle"
  done < <(find "$embedded_framework/Versions" -depth -type d \( -name '*.xpc' -o -name '*.app' \) | sort)
  codesign "${codesign_options[@]}" "$embedded_framework"
fi

codesign "${codesign_options[@]}" "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "$app_dir"

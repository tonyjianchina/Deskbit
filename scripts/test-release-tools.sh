#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
temporary_directory="$(mktemp -d /tmp/deskbit-release-tools.XXXXXX)"
trap 'rm -rf "$temporary_directory"' EXIT

dmg="$temporary_directory/Deskbit.dmg"
key="$temporary_directory/private-key"
appcast="$temporary_directory/appcast.xml"
touch "$dmg" "$key"

VERSION=9.8.7 \
BUILD=42 \
OUT="$appcast" \
SPARKLE_SIGN_UPDATE="$project_dir/Tests/FakeSparkleSignUpdate.sh" \
  "$project_dir/scripts/make-appcast.sh" \
  "$dmg" \
  "$key" \
  "https://example.com/Deskbit.dmg" >/dev/null

xmllint --noout "$appcast"
grep -q '<sparkle:version>42</sparkle:version>' "$appcast"
grep -q '<sparkle:shortVersionString>9.8.7</sparkle:shortVersionString>' "$appcast"
grep -q 'sparkle:edSignature="test-signature"' "$appcast"
grep -q 'https://example.com/Deskbit.dmg' "$appcast"

if SPARKLE_VERSION=0.0.0 "$project_dir/scripts/fetch-sparkle.sh" >/dev/null 2>&1; then
  print -u2 'fetch-sparkle accepted an unverified version override'
  exit 1
fi
if MARKETING_VERSION=invalid "$project_dir/scripts/build-app.sh" >/dev/null 2>&1; then
  print -u2 'build-app accepted an invalid marketing version'
  exit 1
fi

ruby -c "$project_dir/Casks/deskbit.rb" >/dev/null
grep -Eq '^  version "[0-9]+\.[0-9]+\.[0-9]+"$' "$project_dir/Casks/deskbit.rb"
grep -Eq '^  sha256 "[0-9a-f]{64}"$' "$project_dir/Casks/deskbit.rb"
grep -q '^  auto_updates true$' "$project_dir/Casks/deskbit.rb"
grep -q 'depends_on macos: :big_sur' "$project_dir/Casks/deskbit.rb"
grep -Fq 'cp "dist/Deskbit-v${VERSION}-macOS-universal.dmg" "dist/Deskbit-macOS-universal.dmg"' "$project_dir/.github/workflows/release.yml"
sed -n '/^[[:space:]]*ASSETS=(/,/^[[:space:]]*)/p' "$project_dir/.github/workflows/release.yml" \
  | grep -Fq '"dist/Deskbit-macOS-universal.dmg"'

packaged_app="$project_dir/dist/Deskbit.app"
if [ -d "$packaged_app/Contents/Frameworks/Sparkle.framework" ]; then
  info_plist="$packaged_app/Contents/Info.plist"
  [ "$(plutil -extract SUEnableAutomaticChecks raw "$info_plist")" = "true" ]
  [ "$(plutil -extract SUScheduledCheckInterval raw "$info_plist")" = "86400" ]
  test -n "$(plutil -extract SUFeedURL raw "$info_plist")"
  test -n "$(plutil -extract SUPublicEDKey raw "$info_plist")"
  otool -L "$packaged_app/Contents/MacOS/Deskbit" | grep -q 'Sparkle.framework'
fi

print 'release tools: pass'

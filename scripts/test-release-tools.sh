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
grep -q 'version "1.2.2"' "$project_dir/Casks/deskbit.rb"
grep -q '6bb9413d2ced967de2b3bc9fcf8ad8f6e210011837d9e37708a5cbb94e0db659' "$project_dir/Casks/deskbit.rb"

print 'release tools: pass'

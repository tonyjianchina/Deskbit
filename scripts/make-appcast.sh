#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dmg="${1:?DMG path is required}"
private_key_file="${2:?Sparkle private key file is required}"
download_url="${3:?download URL is required}"
version="${VERSION:?VERSION is required}"
build="${BUILD:?BUILD is required}"
output="${OUT:-appcast.xml}"
sign_update="${SPARKLE_SIGN_UPDATE:-$root/Sparkle/bin/sign_update}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must use numeric SemVer (X.Y.Z): $version" >&2
  exit 1
fi
if [[ ! "$build" =~ ^[0-9]+$ ]]; then
  echo "BUILD must be a positive integer: $build" >&2
  exit 1
fi
test -f "$dmg"
test -f "$private_key_file"
test -x "$sign_update"

if [[ "$output" = /* ]]; then
  output_path="$output"
else
  output_path="$root/$output"
fi

signature="$($sign_update --ed-key-file "$private_key_file" "$dmg")"
publication_date="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

mkdir -p "$(dirname "$output_path")"
cat > "$output_path" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Deskbit</title>
    <link>https://github.com/tonyjianchina/Deskbit</link>
    <description>Deskbit app updates</description>
    <language>en</language>
    <item>
      <title>Deskbit ${version}</title>
      <pubDate>${publication_date}</pubDate>
      <sparkle:version>${build}</sparkle:version>
      <sparkle:shortVersionString>${version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>11.0.0</sparkle:minimumSystemVersion>
      <enclosure url="${download_url}" type="application/octet-stream" ${signature} />
    </item>
  </channel>
</rss>
XML

echo "$output_path"

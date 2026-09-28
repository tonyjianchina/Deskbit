#!/bin/bash
set -euo pipefail

version="${SPARKLE_VERSION:-2.9.6}"
default_sha256="52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192"
expected_sha256="${SPARKLE_SHA256:-}"
if [ "$version" = "2.9.6" ] && [ -z "$expected_sha256" ]; then
  expected_sha256="$default_sha256"
fi
if [ -z "$expected_sha256" ]; then
  echo "SPARKLE_SHA256 is required when overriding SPARKLE_VERSION" >&2
  exit 1
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
destination="$root/Sparkle"

if [ -d "$destination/Sparkle.framework" ] && [ -x "$destination/bin/sign_update" ] && [ -z "${FORCE:-}" ]; then
  echo "Sparkle $version is already available at $destination"
  exit 0
fi

temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
archive="$temporary_directory/Sparkle.tar.xz"
url="https://github.com/sparkle-project/Sparkle/releases/download/${version}/Sparkle-${version}.tar.xz"

curl --fail --location --silent --show-error --output "$archive" "$url"

actual_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
if [ "$actual_sha256" != "$expected_sha256" ]; then
  echo "Sparkle checksum mismatch" >&2
  echo "expected: $expected_sha256" >&2
  echo "actual:   $actual_sha256" >&2
  exit 1
fi

mkdir -p "$temporary_directory/extracted"
tar -xJf "$archive" -C "$temporary_directory/extracted"

rm -rf "$destination"
mkdir -p "$destination"
ditto "$temporary_directory/extracted/Sparkle.framework" "$destination/Sparkle.framework"
ditto "$temporary_directory/extracted/bin" "$destination/bin"

test -x "$destination/bin/sign_update"
echo "Sparkle $version installed at $destination"

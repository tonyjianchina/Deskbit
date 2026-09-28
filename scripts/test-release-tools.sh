#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"

if MARKETING_VERSION=invalid "$project_dir/scripts/build-app.sh" >/dev/null 2>&1; then
  print -u2 'build-app accepted an invalid marketing version'
  exit 1
fi

ruby -c "$project_dir/Casks/deskbit.rb" >/dev/null
grep -Eq '^  version "[0-9]+\.[0-9]+\.[0-9]+"$' "$project_dir/Casks/deskbit.rb"
grep -Eq '^  sha256 "[0-9a-f]{64}"$' "$project_dir/Casks/deskbit.rb"
grep -q 'depends_on macos: :big_sur' "$project_dir/Casks/deskbit.rb"
grep -Fq 'cp "dist/Deskbit-v${VERSION}-macOS-universal.dmg" "dist/Deskbit-macOS-universal.dmg"' "$project_dir/.github/workflows/release.yml"
sed -n '/^[[:space:]]*ASSETS=(/,/^[[:space:]]*)/p' "$project_dir/.github/workflows/release.yml" \
  | grep -Fq '"dist/Deskbit-macOS-universal.dmg"'

print 'release tools: pass'

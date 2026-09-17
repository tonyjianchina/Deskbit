#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
probe_binary="$(mktemp /tmp/deskbit-feedback-submission.XXXXXX)"
trap 'rm -f "$probe_binary"' EXIT

swiftc \
  "$project_dir/Sources/Deskbit/FeedbackSubmission.swift" \
  "$project_dir/Tests/FeedbackSubmissionProbe.swift" \
  -o "$probe_binary"

"$probe_binary"

#!/usr/bin/env bash
# Run by `make book` before `quarto render`. Generates
# <course-dir>/title-page.tex from the tracked
# <course-dir>/title-page.tex.in template, filling in:
#   - the current version, replacing @@VERSION@@
#   - a release-history table built from the course's git tags
#     (<course>/vX.Y.Z), replacing @@VERSION_HISTORY@@
# so both reflect actual repo state instead of being hand-maintained.
#
# Usage: generate-title-page.sh <course-dir> <version> [extra-tag-pattern]
#
# extra-tag-pattern: optional for-each-ref pattern for tags that predate
# per-course prefixes (e.g. 'refs/tags/v*' for dns-dnssec-for-operators,
# whose v0.6.x releases were tagged before the repo held several courses).
set -euo pipefail
course_dir="$(cd "$1" && pwd)"
course="$(basename "$course_dir")"
version="$2"
extra_pattern="${3:-}"
template="$course_dir/title-page.tex.in"
output="$course_dir/title-page.tex"

rows_file="$(mktemp)"
trap 'rm -f "$rows_file"' EXIT
# shellcheck disable=SC2086  # $extra_pattern is intentionally unquoted (may be empty)
git -C "$course_dir" for-each-ref --sort=-creatordate \
  --format='%(refname:short) & %(creatordate:short) \\' \
  "refs/tags/$course/" $extra_pattern \
  | sed "s|^$course/||" > "$rows_file"

sed -e "s/@@VERSION@@/$version/" \
    -e "/@@VERSION_HISTORY@@/r $rows_file" \
    -e "/@@VERSION_HISTORY@@/d" \
    "$template" > "$output"

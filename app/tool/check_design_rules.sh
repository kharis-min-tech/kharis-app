#!/usr/bin/env bash
# Design rules for the Kharis redesign. Run from anywhere:
#
#     tool/check_design_rules.sh
#
# 1. lib/theme/kharis_tokens.g.dart must match tokens/kharis_tokens.json:
#    the generator is run and the check fails if the file changes.
# 2. No raw colours or font sizes in lib/ outside lib/theme/ and
#    lib/ui/components/: `Color(0x`, `Colors.` and `fontSize:` are not
#    allowed. Colours come from `context.k`, text from KharisText.
#
# Screens written before the redesign still break rule 2. They are listed in
# tool/design_rules_baseline.txt and skipped. That list can only shrink: the
# check fails if a listed file is gone or has become clean (remove its line),
# and it fails on any violation in a file that is not listed.
set -euo pipefail
export LC_ALL=C

cd "$(dirname "$0")/.."

GENERATED=lib/theme/kharis_tokens.g.dart
BASELINE=tool/design_rules_baseline.txt
# `Colors.` must not be part of a longer name such as AppColors.
PATTERN='Color\(0x|(^|[^A-Za-z0-9_])Colors\.|fontSize:'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=0

# ── 1. Generated tokens are up to date ──────────────────────────────────────
cp "$GENERATED" "$tmp/tokens.before"
python3 tool/generate_tokens.py >/dev/null
if ! cmp -s "$GENERATED" "$tmp/tokens.before"; then
  echo "ERROR: $GENERATED was out of date with tokens/kharis_tokens.json."
  echo "  It has been regenerated: commit the result. Never edit it by hand."
  failed=1
fi

# ── 2. No raw colours or font sizes outside the theme and components ───────
{ grep -rlE --include='*.dart' "$PATTERN" lib || true; } \
  | { grep -vE '^lib/(theme|ui/components)/' || true; } \
  | sort -u >"$tmp/violators"
{ grep -vE '^[[:space:]]*(#|$)' "$BASELINE" || true; } | sort -u >"$tmp/baseline"

while IFS= read -r file; do
  if [ ! -f "$file" ]; then
    echo "ERROR: $BASELINE lists $file, which no longer exists. Remove the line."
    failed=1
  fi
done <"$tmp/baseline"

comm -13 "$tmp/violators" "$tmp/baseline" >"$tmp/clean"
while IFS= read -r file; do
  if [ -f "$file" ]; then
    echo "ERROR: $file no longer breaks the design rules. Remove it from $BASELINE."
    failed=1
  fi
done <"$tmp/clean"

comm -23 "$tmp/violators" "$tmp/baseline" >"$tmp/new"
while IFS= read -r file; do
  echo "ERROR: $file uses a raw colour or font size:"
  grep -nE "$PATTERN" "$file" | sed 's/^/    /'
  failed=1
done <"$tmp/new"

if [ "$failed" -ne 0 ]; then
  echo
  echo "Design rules failed. Use context.k for colours and KharisText for text;"
  echo "raw values belong in tokens/kharis_tokens.json."
  exit 1
fi

echo "Design rules pass ($(wc -l <"$tmp/baseline" | tr -d ' ') legacy files still baselined)."

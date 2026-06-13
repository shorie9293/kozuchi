#!/usr/bin/env bash
# coverage.sh - Flutter test coverage measurement for kozuchi
#
# Usage: ./scripts/coverage.sh
#
# Prerequisites:
#   - lcov package installed (sudo apt-get install -y lcov)
#   - Flutter SDK available
#
# Steps:
#   1. flutter pub get
#   2. flutter test --no-pub --coverage (with TMPDIR=~/tmp_flutter if /tmp is full)
#   3. genhtml coverage/lcov.info -o coverage/html
#   4. lcov --summary coverage/lcov.info

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> Step 1: flutter pub get"
flutter pub get

echo ""
echo "==> Step 2: flutter test --no-pub --coverage"
if [ -d "$HOME/tmp_flutter" ] && [ "$(df /tmp --output=pcent | tail -1 | tr -dc '0-9')" -gt 90 ] 2>/dev/null; then
  TMPDIR="$HOME/tmp_flutter" flutter test --no-pub --coverage
else
  # Use ~/tmp_flutter anyway if it exists, to be safe
  if [ -d "$HOME/tmp_flutter" ]; then
    TMPDIR="$HOME/tmp_flutter" flutter test --no-pub --coverage
  else
    flutter test --no-pub --coverage
  fi
fi

echo ""
echo "==> Step 3: genhtml coverage/lcov.info -o coverage/html"
genhtml coverage/lcov.info -o coverage/html

echo ""
echo "==> Step 4: lcov --summary coverage/lcov.info"
lcov --summary coverage/lcov.info

echo ""
echo "Done. Open coverage/html/index.html to view the report."

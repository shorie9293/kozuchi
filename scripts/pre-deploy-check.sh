#!/bin/bash
# ⛩️ Pre-deploy check — デプロイ前に CI 同等の全チェックをローカル実行
# 八百万の掟：デプロイ前には必ずこのスクリプトを通せ
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⛩️  Pre-deploy check: kozuchi"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Step 1: flutter pub get ---
echo ""
echo "[1/3] 📦 flutter pub get..."
flutter pub get
echo "✅ pub get OK"

# --- Step 2: flutter analyze ---
echo ""
echo "[2/3] 🔍 flutter analyze --no-fatal-infos..."
flutter analyze --no-fatal-infos
echo "✅ analyze OK (no warnings or errors)"

# --- Step 3: flutter test ---
echo ""
echo "[3/3] 🧪 flutter test..."
flutter test
echo "✅ all tests passed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Pre-deploy check PASSED — safe to deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

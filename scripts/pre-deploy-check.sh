#!/bin/bash
# ⛩️ Pre-deploy check — デプロイ前に CI 同等の全チェックをローカル実行
# kozuchi 専用：CI 相当の 3-shard テスト構造で P5 ハング（長時間一括試験）を回避
# 八百万の掟：デプロイ前には必ずこのスクリプトを通せ
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⛩️  Pre-deploy check: kozuchi"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Step 1: flutter pub get ---
echo ""
echo "[1/5] 📦 flutter pub get..."
flutter pub get
echo "✅ pub get OK"

# --- Step 2: flutter analyze ---
echo ""
echo "[2/5] 🔍 flutter analyze --no-fatal-infos..."
flutter analyze --no-fatal-infos
echo "✅ analyze OK (no warnings or errors)"

# --- Step 3: Test shard 1/3 (core + domain — 純ロジック) ---
echo ""
echo "[3/5] 🧪 test shard 1/3 (core + domain)..."
flutter test --no-pub -j 2 test/core/ test/domain/
echo "✅ shard 1/3 passed"

# --- Step 4: Test shard 2/3 (features グループA) ---
echo ""
echo "[4/5] 🧪 test shard 2/3 (features A)..."
flutter test --no-pub -j 1 \
  test/features/achievements/ \
  test/features/advisor_selection/ \
  test/features/analysis_chart/ \
  test/features/budget/ \
  test/features/careerCoach/ \
  test/features/collaboration_dashboard/ \
  test/features/csv_export/ \
  test/features/daily_quest/ \
  test/features/effects/ \
  test/features/exp_gauge/ \
  test/features/goal/ \
  test/features/goals/ \
  test/features/goal_spending/ \
  test/features/hp_bar/
echo "✅ shard 2/3 passed"

# --- Step 5: Test shard 3/3 (features グループB) ---
echo ""
echo "[5/5] 🧪 test shard 3/3 (features B)..."
flutter test --no-pub -j 1 \
  test/features/income/ \
  test/features/main_screen/ \
  test/features/pinch_zone/ \
  test/features/receipt_scanner/ \
  test/features/rpg_task_bonus/ \
  test/features/satori/ \
  test/features/shared/ \
  test/features/spending_chart/ \
  test/features/summary_chart/ \
  test/features/transaction_filter/ \
  test/features/transaction_history/ \
  test/features/trial_quest/ \
  test/features/tsundoku/ \
  test/features/tutorial/ \
  test/features/weekly_quest/ \
  test/features/weekly_report/
echo "✅ shard 3/3 passed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Pre-deploy check PASSED — safe to deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# コヅチ第1陣改善計画 — 目標支出ゲージ化・収入削除・カテゴリ選択UI

> **For Hermes:** Use yaoyorozu-dev-cycle skill to implement this plan task-by-task.

**Goal:** HPバーを「今月の目標支出 消化率ゲージ」に変更。収入カードを目標カードに置換。支出入力画面にカテゴリ選択UIを追加。

**Architecture:** 
- `HpBarWidget` → `GoalSpendingGauge`（目標支出消化率を主役に。支出でゲージ上昇＝RPGのEXP的）
- 収入カード → 目標カード（今月の目標進捗を一目で）
- `OfferingInputScreen` にカテゴリ選択チップ追加（自動分類＋手動選択可能）

**Tech Stack:** Flutter 3.27.4, shared_preferences, keyword_category_map.json

**現バージョン:** v1.0.4+31, 92試験

---

## 事前確認：ベースライン試験

```bash
cd ~/Takamagahara/utsushiyo/kozuchi
export PATH="/tmp/flutter/bin:$PATH"
flutter pub get && flutter test 2>&1 | tail -5
# 期待: All tests passed!
```

---

## Task 1: GoalSpendingGauge 新設（HpBarWidget の代替）

**Objective:** 支出でゲージが増える「目標支出消化率ゲージ」Widgetを新設

**Files:**
- Create: `lib/features/goal_spending/presentation/widgets/goal_spending_gauge.dart`
- Create: `test/features/goal_spending/goal_spending_gauge_test.dart`

**設計:**
- 入力: `monthlyBudget` (int), `totalSpent` (int), `remainingDays` (int)
- 消化率 = totalSpent / monthlyBudget（0〜100%以上）
- バー色: 緑(〜50%)→黄(〜80%)→橙(〜100%)→赤(超過)
- 表示: 「今月の目標支出」「¥XX,XXX / ¥YYY,YYY」「残りXX日」「¥Z,ZZZ/日」
- 予算未設定時は「目標を設定してください」プロンプト

### Step 1: テストを書く（RED）

```dart
// test/features/goal_spending/goal_spending_gauge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kozuchi/features/goal_spending/presentation/widgets/goal_spending_gauge.dart';

void main() {
  group('GoalSpendingGauge', () {
    testWidgets('予算設定済みの場合、目標支出の消化率が表示される', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 150000,
              totalSpent: 45000,
              remainingDays: 20,
            ),
          ),
        ),
      );
      // ラベル
      expect(find.text('今月の目標支出'), findsOneWidget);
      // 消化率 30%
      expect(find.text('30%'), findsOneWidget);
      // 残予算 105,000
      expect(find.textContaining('105,000'), findsOneWidget);
      // 日割り 5,250
      expect(find.textContaining('5,250'), findsOneWidget);
    });

    testWidgets('予算超過時は警告表示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 150000,
              totalSpent: 165000,
              remainingDays: 5,
            ),
          ),
        ),
      );
      expect(find.textContaining('予算超過'), findsOneWidget);
      expect(find.text('110%'), findsOneWidget);
    });

    testWidgets('予算未設定時は設定促しを表示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 0,
              totalSpent: 0,
              remainingDays: 0,
            ),
          ),
        ),
      );
      expect(find.textContaining('目標を設定'), findsOneWidget);
    });

    testWidgets('onTapBudget コールバックが呼ばれる', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalSpendingGauge(
              monthlyBudget: 0,
              totalSpent: 0,
              remainingDays: 0,
              onTapBudget: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.textContaining('目標を設定'));
      expect(tapped, isTrue);
    });
  });
}
```

### Step 2: テスト実行 → 失敗確認

```bash
flutter test test/features/goal_spending/goal_spending_gauge_test.dart
# 期待: FAIL — GoalSpendingGauge not found
```

### Step 3: 実装（GREEN）

```dart
// lib/features/goal_spending/presentation/widgets/goal_spending_gauge.dart
import 'package:flutter/material.dart';

class GoalSpendingGauge extends StatelessWidget {
  final int monthlyBudget;
  final int totalSpent;
  final int remainingDays;
  final VoidCallback? onTapBudget;

  const GoalSpendingGauge({
    super.key,
    required this.monthlyBudget,
    required this.totalSpent,
    required this.remainingDays,
    this.onTapBudget,
  });

  bool get _isBudgetSet => monthlyBudget > 0;

  int get _remainingBudget {
    final r = monthlyBudget - totalSpent;
    return r < 0 ? 0 : r;
  }

  bool get _isOverBudget => totalSpent > monthlyBudget;

  double get _usagePercent =>
      monthlyBudget > 0 ? (totalSpent / monthlyBudget * 100).clamp(0, 200) : 0;

  int get _dailyAllowance {
    if (remainingDays <= 0) return 0;
    if (_remainingBudget <= 0) return 0;
    return _remainingBudget ~/ remainingDays;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBudgetSet) {
      return _buildNotSet(context);
    }
    return _buildGauge(context);
  }

  Widget _buildNotSet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTapBudget,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今月の目標支出',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'タップして目標額を設定',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildGauge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayPercent = _usagePercent > 100 ? 100.0 : _usagePercent;
    final barColor = _isOverBudget
        ? Colors.red
        : _usagePercent > 80
            ? Colors.orange
            : _usagePercent > 50
                ? Colors.amber
                : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            barColor.withValues(alpha: 0.08),
            barColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // タイトル行
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '今月の目標支出',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_isOverBudget)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('⚠️ 予算超過',
                    style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 消化率バー
          _buildProgressBar(barColor, displayPercent),
          const SizedBox(height: 10),
          // 数値グリッド
          _buildStatsGrid(colorScheme, barColor),
        ],
      ),
    );
  }

  Widget _buildProgressBar(Color barColor, double displayPercent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('消化率', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(
              '${_usagePercent.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: displayPercent / 100.0,
            backgroundColor: barColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(ColorScheme colorScheme, Color accentColor) {
    return Row(
      children: [
        _buildStatItem('残予算', '¥${_format(_remainingBudget)}', colorScheme, Colors.green),
        const SizedBox(width: 8),
        _buildStatItem('残日数', '$remainingDays日', colorScheme, accentColor),
        const SizedBox(width: 8),
        _buildStatItem('月予算', '¥${_format(monthlyBudget)}', colorScheme, colorScheme.primary),
        const SizedBox(width: 8),
        _buildStatItem('日割', '¥${_format(_dailyAllowance)}', colorScheme,
            _isOverBudget ? Colors.red : Colors.orange),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, ColorScheme colorScheme, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label,
              style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _format(int amount) {
    if (amount >= 10000) {
      final man = (amount / 10000).toStringAsFixed(1);
      if (man.endsWith('.0')) return '${amount ~/ 10000}万';
      return '${man}万';
    }
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
```

### Step 4: テスト通過確認

```bash
flutter test test/features/goal_spending/goal_spending_gauge_test.dart
# 期待: 4 tests passed
```

### Step 5: Commit

```bash
git add lib/features/goal_spending/ test/features/goal_spending/
git commit -m "feat: GoalSpendingGauge 新設 — 目標支出消化率ゲージ"
```

---

## Task 2: main_screen の収入カード→目標カード置換

**Objective:** 「💰 収入」カードを「🎯 目標」カードに置換。`GoalSpendingGauge` と予算設定導線を統合

**Files:**
- Modify: `lib/screens/main_screen.dart`

**変更内容:**
1. `_buildIncomeCard()` → `_buildGoalCard()` に改名・置換
2. 内部で `GoalSpendingGauge` を使用
3. 収入記録ボタン削除、予算設定ボタンを目立たせる
4. `_openIncomeInput()` はコード内に残すが導線削除
5. `DailyBudgetWidget`（日割り予算表示）は `GoalSpendingGauge` に統合されるため削除
6. `_buildCardGrid()` の収入カードを目標カードに置換

### Step 1: テストを更新（RED）

```dart
// test/features/main_screen/main_screen_test.dart の該当部分を修正
// 「収入を記録」ボタンが存在しないこと
// 「今月の目標支出」が表示されること
```

### Step 2: 実装

```dart
// _buildCardGrid 内の Row を変更
// Row(
//   children: [
//     Expanded(child: _buildGoalCard(colorScheme)),  // 旧: _buildIncomeCard
//     const SizedBox(width: 12),
//     Expanded(child: _buildTrialCard(colorScheme)),
//   ],
// ),

// _buildGoalCard:
Widget _buildGoalCard(ColorScheme colorScheme) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GoalSpendingGauge(
            monthlyBudget: _budgetAmount,
            totalSpent: _monthlyExpenditure,
            remainingDays: _displayBudget.remainingDays,
            onTapBudget: _budgetAmount == 0 ? _openBudgetSettings : null,
          ),
        ],
      ),
    ),
  );
}
```

### Step 3: Commit

```bash
git add lib/screens/main_screen.dart test/features/main_screen/main_screen_test.dart
git commit -m "feat: 収入カード→目標カード置換、GoalSpendingGauge統合"
```

---

## Task 3: HPバー表示の簡略化（主役を GoalSpendingGauge に譲る）

**Objective:** 既存の `HpBarWidget` を画面最上部から外し、画面下部のカード内にコンパクト表示に変更

**Files:**
- Modify: `lib/screens/main_screen.dart`（`_buildHpExpCompactRow` の変更）
- Modify: `lib/features/hp_bar/presentation/widgets/hp_bar_widget.dart`（任意）

**変更内容:**
- `_buildHpExpCompactRow` を削除し、代わりに `GoalSpendingGauge` を最上部に配置
- または `HpBarWidget` を残しつつ、`GoalSpendingGauge` をその上に表示

判断：HPバー（残高）はkozuchiのコア体験である「生活防衛ライン」の概念があるため、完全削除せずにコンパクト化する。メイン上部は `GoalSpendingGauge` を主役に据える。

```dart
// build() 内の Column children を変更:
children: [
  // 🎯 目標支出ゲージ（主役・最上部）
  GoalSpendingGauge(
    monthlyBudget: _budgetAmount,
    totalSpent: _monthlyExpenditure,
    remainingDays: _displayBudget.remainingDays,
    onTapBudget: _budgetAmount == 0 ? _openBudgetSettings : null,
  ),
  const SizedBox(height: 8),
  // HP/EXPコンパクト表示（コンパクト化）
  _buildHpExpCompactRow(colorScheme),
  // ... 以下既存
],
```

### Step 1: テスト修正

```bash
# main_screen_test の既存テストを新しい配置に合わせて修正
flutter test test/features/main_screen/main_screen_test.dart
```

### Step 2: Commit

```bash
git add lib/screens/main_screen.dart test/features/main_screen/
git commit -m "feat: GoalSpendingGauge を画面最上部の主役に据える"
```

---

## Task 4: 支出入力にカテゴリ選択UIを追加

**Objective:** `OfferingInputScreen` にカテゴリ選択チップを追加。自動分類結果をプリセットし、ユーザーが変更可能に。

**Files:**
- Modify: `lib/features/trial_quest/presentation/screens/offering_input_screen.dart`
- Modify: `lib/features/trial_quest/presentation/screens/trial_quest_screen.dart`（カテゴリ受け渡し確認）
- Create: `test/features/trial_quest/offering_input_category_test.dart`

**設計:**
- カテゴリ一覧: `['食費', '娯楽', '交通', '光熱費', '交際費', 'その他']`
- 絵文字マッピング: `{'食費': '🍙', '娯楽': '🎮', '交通': '🚃', '光熱費': '💡', '交際費': '🎁', 'その他': '📦'}`
- 用途（`purposeController`）の入力に応じて `ClassifierService.classify()` を実行し、該当カテゴリを初期選択
- ユーザーがチップをタップして上書き可能
- 選択されたカテゴリは `OfferingResult` に `category` フィールドとして追加

### Step 1: OfferingResult に category 追加

```dart
// offering_input_screen.dart の OfferingResult
class OfferingResult {
  final int amount;
  final String purpose;
  final String note;
  final String? receiptImagePath;
  final String? category;  // ← 追加
  final PlayerModel updatedPlayer;

  OfferingResult({
    required this.amount,
    required this.purpose,
    required this.note,
    this.receiptImagePath,
    this.category,  // ← 追加
    required this.updatedPlayer,
  });
}
```

### Step 2: カテゴリ選択UI実装

```dart
// offering_input_screen.dart の State に追加
String? _selectedCategory;

static const Map<String, String> _categoryEmojis = {
  '食費': '🍙',
  '娯楽': '🎮',
  '交通': '🚃',
  '光熱費': '💡',
  '交際費': '🎁',
  'その他': '📦',
};

static const List<String> _categories = ['食費', '娯楽', '交通', '光熱費', '交際費', 'その他'];

// build() 内、用途入力欄の後に追加:
const SizedBox(height: 16),
Text('カテゴリ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
const SizedBox(height: 8),
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: _categories.map((cat) => ChoiceChip(
    label: Text('${_categoryEmojis[cat]} $cat'),
    selected: _selectedCategory == cat,
    onSelected: (selected) {
      setState(() => _selectedCategory = selected ? cat : null);
    },
  )).toList(),
),
```

### Step 3: 用途入力に応じた自動分類

```dart
// _purposeController にリスナー追加（initState 内）
_purposeController.addListener(() {
  final text = _purposeController.text;
  if (text.length >= 2) {
    final result = ClassifierService.instance.classify(text);
    if (result.isClassified && _selectedCategory == null) {
      setState(() => _selectedCategory = result.category);
    }
  }
});
```

### Step 4: _submit でカテゴリを含める

```dart
void _submit() {
  // ...
  Navigator.of(context).pop(OfferingResult(
    amount: amount,
    purpose: _purposeController.text,
    note: _noteController.text,
    receiptImagePath: _receiptImagePath,
    category: _selectedCategory,  // ← 追加
    updatedPlayer: updatedPlayer,
  ));
}
```

### Step 5: テスト

```dart
// test/features/trial_quest/offering_input_category_test.dart
testWidgets('カテゴリチップが6つ表示される', (tester) async { ... });
testWidgets('カテゴリ選択→選択状態が反映される', (tester) async { ... });
testWidgets('選択カテゴリがOfferingResultに含まれる', (tester) async { ... });
```

### Step 6: Commit

```bash
git add lib/features/trial_quest/presentation/screens/offering_input_screen.dart
git add lib/features/trial_quest/presentation/screens/trial_quest_screen.dart
git add test/features/trial_quest/
git commit -m "feat: 支出入力にカテゴリ選択UI追加"
```

---

## Task 5: TrialQuestScreen でカテゴリを受け渡し

**Objective:** `OfferingResult.category` を `TrialQuest.classifiedCategory` に正しく渡す

**Files:**
- Modify: `lib/features/trial_quest/presentation/screens/trial_quest_screen.dart`

### Step 1: 変更

```dart
// _openOfferingInput() 内、OfferingResult の処理:
final updatedQuest = _quest.recordOffering(
  amount: result.amount,
  purpose: result.purpose,
  note: result.note,
  classifiedCategory: result.category,  // result.category を渡す（null許容）
);
```

### Step 2: Commit

```bash
git add lib/features/trial_quest/presentation/screens/trial_quest_screen.dart
git commit -m "fix: OfferingResult.category を TrialQuest.classifiedCategory に接続"
```

---

## Task 6: 日割り予算ウィジェット削除（GoalSpendingGauge に統合済）

**Objective:** `DailyBudgetWidget` が `main_screen` から削除されたことを確認。import も整理。

**Files:**
- Modify: `lib/screens/main_screen.dart`（import 整理）

### Step 1: import 整理と未使用変数削除

```dart
// 削除する import:
// import 'package:kozuchi/features/budget/presentation/widgets/daily_budget_widget.dart';
// 
// _displayBudget の使用が残っていれば整理
```

### Step 2: 全試験通過確認

```bash
flutter analyze --no-fatal-infos && flutter test 2>&1 | tail -5
# 期待: No issues found + All tests passed!
```

### Step 3: Commit

```bash
git add lib/screens/main_screen.dart
git commit -m "refactor: DailyBudgetWidgetのimport整理、GoalSpendingGaugeへの統合完了"
```

---

## Task 7: 最終確認・AppBarバージョン標識更新

**Objective:** 全試験通過、lint 警告ゼロを確認。バージョン bump。

### Step 1: 最終確認

```bash
cd ~/Takamagahara/utsushiyo/kozuchi
export PATH="/tmp/flutter/bin:$PATH"
flutter analyze --no-fatal-infos
flutter test 2>&1 | tail -5
```

### Step 2: pubspec.yaml バージョン bump

```bash
# v1.0.4+31 → v1.1.0+32
sed -i 's/^version: 1.0.4+31/version: 1.1.0+32/' pubspec.yaml
```

### Step 3: Commit

```bash
git add pubspec.yaml
git commit -m "chore: bump version to 1.1.0+32 for goal-spending-gauge + category-select"
```

---

## 試験影響範囲

| ファイル | 影響 | 対応 |
|---------|------|------|
| `hp_bar_widget_test.dart` | HPバー関連の文言変更 | 文言更新（「残高（HP）」→新文言） |
| `main_screen_test.dart` | 収入カード→目標カード置換 | finder 更新 |
| `player_model_test.dart` | 既存モデル挙動不変 | 変更不要（モデルはそのまま） |
| `daily_budget_widget_test.dart` | Widget削除に伴い失敗の可能性 | 削除または更新 |
| `offering_input_screen` 関連テスト | 新UI要素追加 | 修正＋新規追加 |

---

## Risks

- **Hive後方互換**: `PlayerModel.hp` フィールドは変更しないため、既存データは破損しない
- **Pre-push hook**: `flutter analyze --no-fatal-infos` が warning 0 であることを確認
- **画面レイアウト**: `GoalSpendingGauge` を最上部に配置することで、既存の `HpBarWidget` + `DailyBudgetWidget` の二重表示を避ける

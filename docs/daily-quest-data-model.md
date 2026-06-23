# デイリークエスト データモデル設計書

**制定**: 令和八年水無月二十三日 (2026-06-23)
**担当**: t_5d3b52cd (天照大神)
**下流タスク**: t_441942bc (割当), t_6aa97c93 (検出/進捗), t_d6a8627e (UI), t_350c9129 (報酬/罰)
**プロジェクト**: kozuchi (打ち出の小槌)
**試験**: 214/214通過 (現行)

---

## 1. ドメインモデル

### 1.1 DailyQuestType (enum)

5種類のクエストタイプ。各タイプは異なる検出条件・報酬値を持つ。

```dart
enum DailyQuestType {
  spendOnSelf(    label: '自分に使え',   expReward: 80,  satoriPenalty: 10),
  receiptScan(    label: 'レシート撮影', expReward: 100, satoriPenalty: 10),
  newCategory(    label: '新カテゴリ支出', expReward: 120, satoriPenalty: 10),
  underBudget(    label: '予算以内',     expReward: 60,  satoriPenalty: 5),
  noSpending(     label: '無支出の日',   expReward: 150, satoriPenalty: 20),
}
```

| enum値 | 表示ラベル | EXP報酬 | SATORI減 | 検出条件 | 目標値の意味 |
|--------|-----------|---------|----------|---------|------------|
| `spendOnSelf` | 自分に使え | 80 | 10 | 自己投資カテゴリ (カテゴリ≠食費/光熱費/家賃/交通費等の必須支出) への支出額 | targetValue=金額(円)。例: 1000→¥1,000以上の自己投資支出 |
| `receiptScan` | レシート撮影 | 100 | 10 | ReceiptScannerScreenでの撮影+保存成功 | targetValue=枚数。例: 3→3枚撮影 |
| `newCategory` | 新カテゴリ支出 | 120 | 10 | 過去30日間使用実績のないカテゴリでの支出 | targetValue=1固定。達成条件: 新規カテゴリ使用1回 |
| `underBudget` | 予算以内 | 60 | 5 | その日の総支出額がBudgetRepositoryの日次予算以下 | targetValue=予算額(円)。例: 5000→¥5,000以内 |
| `noSpending` | 無支出の日 | 150 | 20 | その日の支出エントリ数が0 | targetValue=0固定。達成条件: 支出ゼロ |

**拡張性**: 新タイプ追加時は enum値追加 + 下記 QuestDetector に対応する検出メソッド追加 で対応。

### 1.2 DailyQuest (immutable model)

```dart
class DailyQuest {
  final String id;              // ランダム12桁英数字
  final DailyQuestType type;    // クエストタイプ
  final String title;           // 表示タイトル (例: "自分に使え：¥1,000")
  final String description;     // 説明文
  final int targetValue;        // 目標値
  final int currentProgress;    // 現在進捗 (0〜targetValue)
  final bool isCompleted;       // 達成済みか
  final bool isFailed;          // 失敗か (日跨ぎ未達成)
  final DateTime dateAssigned;  // 割当日時
  final DateTime? dateCompleted;// 達成日時
  final int expReward;          // 達成時EXP報酬
  final int satoriPenalty;      // 未達成時SATORI減少量
}
```

**不変性の掟**: 全フィールドはfinal。状態変更は `updateProgress()` / `markAsFailed()` が新しいインスタンスを返す。

**主要メソッド**:
- `updateProgress(int newProgress)` → DailyQuest: 進捗更新。目標値以上でisCompleted=true & dateCompleted=現在時刻。完了済みの場合は更新しない。
- `markAsFailed()` → DailyQuest: 失敗マーク (isFailed=true)。
- `progressRatio` → double: 0.0〜1.0 の進捗率（targetValue=0の場合は1.0を返しゼロ除算回避済）。
- `toJson()` / `DailyQuest.fromJson()`: JSON直列化・復元。

### 1.3 DailyQuestState (日次集約)

```dart
class DailyQuestState {
  final DateTime date;              // この状態の日付
  final List<DailyQuest> quests;    // 割当クエスト一覧 (最大3件)
}
```

**主要ゲッター**:
- `isToday`: date == 今日の日付
- `pendingQuests`: 未完了かつ未失敗のクエスト一覧
- `completedQuests`: 完了済みクエスト一覧
- `isAllCompleted`: 全クエスト完了 (quests.isNotEmpty && quests.every(isCompleted))
- `totalSatoriPenalty`: 失敗クエストのSATORIペナルティ合計

---

## 2. ストレージスキーマ

### 2.1 ローカル保存 (SharedPreferences) — 現行

**保存キー**: `kozuchi_daily_quests_state`
**保存形式**: JSON文字列
**保存タイミング**: クエスト割当時・進捗更新時・達成時・失敗時
**日跨ぎ検出**: `loadedState.isToday == false` なら新規割当

```json
{
  "date": "2026-06-23T00:00:00.000",
  "quests": [
    {
      "id": "a1b2c3d4e5f6",
      "type": "spendOnSelf",
      "title": "自分に使え：¥1,000",
      "description": "今日は自分のために¥1,000使おう",
      "targetValue": 1000,
      "currentProgress": 0,
      "isCompleted": false,
      "isFailed": false,
      "dateAssigned": "2026-06-23T00:00:00.000",
      "dateCompleted": null,
      "expReward": 80,
      "satoriPenalty": 10
    }
  ]
}
```

**保存処理 (DailyQuestRepository.saveQuests)**:
```dart
Future<void> saveQuests(DailyQuestState state) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('kozuchi_daily_quests_state', jsonEncode(state.toJson()));
}
```

### 2.2 Firestore (将来クラウド同期用) — 設計

ユーザーIDをキーとしたサブコレクション設計。

```
users/{userId}/
├── daily_quest_log/{date}          # 日別クエスト状態
│   ├── date: Timestamp
│   ├── quests: array<QuestDoc>
│   └── daily_summary: {
│       ├── all_completed: bool
│       ├── completed_count: int
│       ├── failed_count: int
│       ├── exp_earned: int          # 獲得EXP合計
│       └── satori_lost: int         # 喪失SATORI合計
│       }
│
├── quest_history/{questId}          # 達成履歴 (後続タスク用)
│   ├── quest_id: string
│   ├── type: string                 # enum名
│   ├── date_assigned: Timestamp
│   ├── date_completed: Timestamp
│   ├── exp_earned: int
│   └── progress_final: int
│
└── player_stats/quests              # クエスト統計
    ├── streak_current: int          # 連続全達成日数
    ├── streak_best: int             # 最高連続全達成日数
    ├── total_completed: int         # 累計達成数
    └── last_activity_date: Timestamp
```

**Firestoreセキュリティルール**:
```
match /users/{userId}/daily_quest_log/{date} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
match /users/{userId}/quest_history/{questId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

**QuestDoc サブドキュメント型**:
```dart
// Firestore上のquests配列要素
Map<String, dynamic> questToFirestore(DailyQuest quest) => {
  'id': quest.id,
  'type': quest.type.name,
  'title': quest.title,
  'targetValue': quest.targetValue,
  'currentProgress': quest.currentProgress,
  'isCompleted': quest.isCompleted,
  'isFailed': quest.isFailed,
  'dateAssigned': Timestamp.fromDate(quest.dateAssigned),
  'dateCompleted': quest.dateCompleted != null
      ? Timestamp.fromDate(quest.dateCompleted!)
      : null,
  'expReward': quest.expReward,
  'satoriPenalty': quest.satoriPenalty,
};
```

---

## 3. クエスト割当戦略 (t_441942bc 向け設計)

### 3.1 割当タイミング

| トリガー | 条件 |
|---------|------|
| アプリ起動時 | `DailyQuestRepository.needsRefresh() == true` |
| 0時跨ぎ検出 | `DateTime.now().day != loadedState.date.day` |
| 手動リフレッシュ | ユーザー操作 (将来のUI追加時) |

### 3.2 選択アルゴリズム

```
入力: 利用可能クエストタイプ一覧, ユーザー状態, 前日のクエスト履歴
出力: List<DailyQuest> (最大3件)

手順:
1. 全5タイプを候補プールとして開始
2. ユーザー状態によるフィルタ:
   - 予算未設定 → underBudget を除外
   - 30日以内の支出カテゴリが全カテゴリ網羅 → newCategory を除外
   - 前日が高額支出日 → spendOnSelf の確率を下げる (重み0.5)
3. 前日との重複回避:
   - 前日に割り当てられたタイプは確率半減 (重み0.5)
   - 前々日に割り当てられたタイプは確率微減 (重み0.8)
4. 重み付きランダム抽選で3タイプを選択
5. 各タイプに目標値を設定:
   - spendOnSelf: 500〜2000円の範囲でランダム (日次の自己投資平均額に応じて調整可)
   - receiptScan: 1〜5枚 (前日の撮影枚数に応じて段階的に増加)
   - newCategory: 1固定
   - underBudget: BudgetRepositoryの日次予算値を採用
   - noSpending: 0固定
6. 各クエストにDailyQuestインスタンスを生成
7. DailyQuestStateに束ねて返却
```

### 3.3 タイトル生成

| タイプ | タイトルパターン | 例 |
|-------|----------------|-----|
| spendOnSelf | `自分に使え：¥{targetValue}` | 自分に使え：¥1,000 |
| receiptScan | `レシートを{targetValue}枚撮れ` | レシートを3枚撮れ |
| newCategory | `新カテゴリで支出せよ` | 新カテゴリで支出せよ |
| underBudget | `今日は¥{targetValue}以内` | 今日は¥5,000以内 |
| noSpending | `無支出の日` | 無支出の日 |

### 3.4 説明文生成

| タイプ | 説明文パターン |
|-------|-------------|
| spendOnSelf | `今日は自分のために¥{targetValue}使おう。自分への投資は心の栄養` |
| receiptScan | `今日のレシートを{targetValue}枚撮影しよう。積み重ねが悟りに繋がる` |
| newCategory | `最近使っていないカテゴリで支出しよう。新しい使い道を開拓せよ` |
| underBudget | `今日の支出を¥{targetValue}以内に抑えよう。節制こそが修行` |
| noSpending | `今日は1円も使わない日。無駄な支出を見直す機会とせよ` |

---

## 4. 進捗検出戦略 (t_6aa97c93 向け設計)

### 4.1 検出フック一覧

各クエストタイプの進捗は以下のイベントで更新される:

| クエストタイプ | 検出イベント | 更新値 | 検出箇所 |
|--------------|------------|--------|---------|
| `spendOnSelf` | 支出エントリ追加時 (カテゴリが自己投資系) | 支出額の累積 (上限targetValue) | TransactionService.addTransaction() 直後 |
| `receiptScan` | レシート撮影成功時 | +1 (上限targetValue) | ReceiptScannerScreen 撮影成功コールバック |
| `newCategory` | 支出エントリ追加時 (30日未使用カテゴリ) | →1 (達成) | TransactionService.addTransaction() 直後 |
| `underBudget` | 支出エントリ追加時 | その日の総支出額 (上限targetValue) | TransactionService.addTransaction() 直後 |
| `noSpending` | 支出エントリ追加時 (支出があれば即失敗) | 0固定 (支出→即markAsFailed) | TransactionService.addTransaction() 直後 |

### 4.2 QuestProgressUpdater (新設クラス)

```dart
/// デイリークエストの進捗更新を統括するサービス
///
/// 各イベントソースから呼び出され、
/// アクティブなクエストの条件と突合して進捗を更新する。
class QuestProgressUpdater {
  final DailyQuestRepository _repository;

  /// 支出エントリ追加時の進捗更新
  /// [amount] 支出額, [category] 支出カテゴリ
  Future<void> onExpenseAdded(int amount, String category) async {
    final state = await _repository.loadQuests();
    if (state == null || !state.isToday) return;

    final updatedQuests = <DailyQuest>[];
    for (final quest in state.quests) {
      if (quest.isCompleted || quest.isFailed) {
        updatedQuests.add(quest);
        continue;
      }
      updatedQuests.add(_updateForExpense(quest, amount, category));
    }
    await _repository.saveQuests(DailyQuestState(quests: updatedQuests));
  }

  DailyQuest _updateForExpense(DailyQuest quest, int amount, String category) {
    switch (quest.type) {
      case DailyQuestType.spendOnSelf:
        if (_isSelfInvestmentCategory(category)) {
          return quest.updateProgress(quest.currentProgress + amount);
        }
        return quest;
      case DailyQuestType.newCategory:
        if (_isNewCategory(category)) {
          return quest.updateProgress(1); // 1回で達成
        }
        return quest;
      case DailyQuestType.underBudget:
        // その日の総支出を取得しprogressとして設定
        final todayTotal = _getTodayTotalExpense();
        return quest.updateProgress(todayTotal);
      case DailyQuestType.noSpending:
        return quest.markAsFailed(); // 支出があれば即失敗
      default:
        return quest;
    }
  }

  /// レシート撮影時の進捗更新
  Future<void> onReceiptScanned() async {
    final state = await _repository.loadQuests();
    if (state == null || !state.isToday) return;

    final updatedQuests = state.quests.map((quest) {
      if (quest.type == DailyQuestType.receiptScan &&
          !quest.isCompleted && !quest.isFailed) {
        return quest.updateProgress(quest.currentProgress + 1);
      }
      return quest;
    }).toList();
    await _repository.saveQuests(DailyQuestState(quests: updatedQuests));
  }
}
```

### 4.3 自己投資カテゴリ判定

「自分に使え」の対象カテゴリ:
- ✅ 趣味・娯楽、書籍、衣服、美容、自己啓発、旅行、外食（嗜好品）
- ❌ 食費（日常）、家賃、光熱費、通信費、交通費（通勤）、医療費、保険

**判定実装**: `CategoryClassifier.isSelfInvestment(String category) → bool`

### 4.4 新規カテゴリ判定

`_isNewCategory(category)`: 過去30日間の支出エントリに同じカテゴリが存在しない場合 true。

---

## 5. UI連携設計 (t_d6a8627e 向け設計)

### 5.1 データフロー

```
DailyQuestRepository (SharedPreferences)
    ↕ loadQuests() / saveQuests()
QuestProgressUpdater (更新ロジック)
    ↕ 状態変更通知
DailyQuestNotifier (Riverpod StateNotifier) [新設]
    ↕ provider watch
DailyQuestWidget (UIコンポーネント)
```

### 5.2 表示データマッピング

| クエストタイプ | アイコン | 進捗表示形式 | 達成エフェクト |
|--------------|---------|------------|-------------|
| spendOnSelf | 💰 | ¥{progress}/¥{target} | 硬貨が舞う |
| receiptScan | 📸 | {progress}/{target}枚 | レシートが重なる |
| newCategory | 🆕 | 達成/未達成 (二値) | カテゴリアイコン出現 |
| underBudget | 📊 | ¥{progress}/¥{target} (少ないほど良い) | 緑の予算バー |
| noSpending | 🔒 | 維持/失敗 (二値) | 南京錠アイコン |

### 5.3 未達成通知

日跨ぎ検出時、前日の未達成クエストがある場合:
1. `totalSatoriPenalty` 分だけSATORI値を減少
2. 「昨日のクエスト未達成: SATORI -{total}」をSnackBar表示
3. 未達成クエストを `markAsFailed()` して履歴に保存

---

## 6. EXP・SATORI連携設計 (t_350c9129 向け設計)

### 6.1 達成時EXPフロー

```
QuestProgressUpdater.onExpenseAdded() で isCompleted=true 検出
  → PlayerRepository から現在のPlayerModelを取得
  → player.addExp(quest.expReward)
  → PlayerRepository.savePlayer(player)
  → SnackBar表示: "🎉 クエスト達成！EXP +{expReward}"
```

### 6.2 日跨ぎ未達成時SATORI減少フロー

```
DailyQuestRepository.loadQuests() で needsRefresh()=true 検出
  → 前日の未達成クエストを収集
  → totalSatoriPenalty を算出
  → PlayerRepository から現在のPlayerModelを取得
  → 新規メソッド player.reduceSatori(penalty) でSATORI値を減少
  → SnackBar表示: "⚠️ 昨日のクエスト未達成: SATORI -{total}"
  → 前日の全未完了クエストを markAsFailed()
```

### 6.3 連続達成ボーナス (将来拡張)

| 連続全達成日数 | EXPボーナス倍率 |
|-------------|--------------|
| 3日 | 1.2x |
| 7日 | 1.5x |
| 14日 | 2.0x |
| 30日 | 3.0x |

---

## 7. ファイル構成

```
kozuchi/lib/
├── domain/models/
│   └── daily_quest.dart          # DailyQuestType enum + DailyQuest + DailyQuestState (既存, 289行)
├── features/daily_quest/
│   ├── data/
│   │   ├── daily_quest_repository.dart     # 永続化リポジトリ (既存, 54行)
│   │   ├── quest_progress_updater.dart     # 進捗更新サービス [新設: t_6aa97c93]
│   │   └── quest_assignment_service.dart   # 割当ロジック [新設: t_441942bc]
│   ├── domain/
│   │   └── quest_detector.dart            # 条件検出ロジック [新設: t_6aa97c93]
│   └── presentation/
│       ├── widgets/
│       │   ├── daily_quest_card.dart       # 個別クエストカード [新設: t_d6a8627e]
│       │   ├── daily_quest_list.dart       # クエスト一覧 [新設: t_d6a8627e]
│       │   └── quest_achievement_effect.dart # 達成エフェクト [新設: t_d6a8627e]
│       └── state/
│           └── daily_quest_notifier.dart   # Riverpod状態管理 [新設: t_d6a8627e]
├── screens/
│   └── main_screen.dart          # 統合: loadQuests + QuestProgressUpdater注入 (既存, 480行)
└── features/shared/data/
    └── player_repository.dart    # 拡張: reduceSatori()追加 [更新: t_350c9129]
```

---

## 8. 設計判断記録

| # | 判断 | 根拠 |
|---|------|------|
| 1 | SharedPreferencesを基本ストレージに継続使用 | 既存コードとの一貫性。最大3件/日なのでKV storeで十分 |
| 2 | Firestoreは将来拡張として設計 | 現段階ではオフライン動作を優先。クラウド同期はマルチデバイス対応時に追加 |
| 3 | 割当は重み付きランダム | 完全ランダムより連続重複を避けつつ多様性を確保 |
| 4 | クエストは最大3件/日 | tsundoku-questの実績 (DailyMission 3件/日) に倣う |
| 5 | updateProgress()は不変パターン | 状態管理の単純化・バグ防止。全モデル統一パターン |
| 6 | noSpendingタイプはtargetValue=0 | 進捗追跡不要の二値型クエスト。progressRatioのゼロ除算はガード済 |
| 7 | SATORIは後日減少・EXPは即時加算 | EXPは達成感を即フィードバック。SATORI減少は「一日の終わりの反省」として日跨ぎ時 |

---

## 9. 試験戦略

### 既存試験 (34件, 全通過)
- `test/domain/models/daily_quest_test.dart` (30件)
- `test/features/daily_quest/data/daily_quest_repository_test.dart` (4件)

### 追加すべき試験 (下流タスク用)

| 試験対象 | 件数目安 | 担当タスク |
|---------|---------|-----------|
| QuestAssignmentService: 割当ロジック・重み付き選択・重複回避 | 10件 | t_441942bc |
| QuestProgressUpdater: 各タイプの進捗更新・エッジケース | 12件 | t_6aa97c93 |
| DailyQuestNotifier: 状態遷移・Provider連携 | 5件 | t_d6a8627e |
| EXP/SATORI連携: 達成時加算・日跨ぎ減少・連続ボーナス | 8件 | t_350c9129 |

---

**本設計書に従い、下流タスク (t_441942bc → t_6aa97c93 → t_d6a8627e → t_350c9129) の順で実装を進められたい。**

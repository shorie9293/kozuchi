import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/features/daily_quest/data/quest_action.dart';
import 'package:kozuchi/features/daily_quest/data/quest_progress_detector.dart';

void main() {
  late QuestProgressDetector detector;

  setUp(() {
    detector = const QuestProgressDetector();
  });

  // ─── ヘルパー ──────────────────────────────────────────
  DailyQuest _quest({
    required String id,
    required DailyQuestType type,
    required int targetValue,
    int currentProgress = 0,
    bool isCompleted = false,
    bool isFailed = false,
  }) {
    return DailyQuest(
      id: id,
      type: type,
      title: 'test quest',
      targetValue: targetValue,
      currentProgress: currentProgress,
      isCompleted: isCompleted,
      isFailed: isFailed,
    );
  }

  DailyQuestState _state(List<DailyQuest> quests) {
    return DailyQuestState(quests: quests);
  }

  // ─── spendOnSelf ──────────────────────────────────────

  group('spendOnSelf', () {
    test('自己投資カテゴリの支出で進捗が加算される', () {
      final quests = [_quest(
        id: 'q1',
        type: DailyQuestType.spendOnSelf,
        targetValue: 1500,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(
          amount: 800,
          category: '書籍',
        ),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q1');
      expect(q.currentProgress, 800);
      expect(q.isCompleted, isFalse);
    });

    test('自己投資カテゴリ以外の支出では進捗しない', () {
      final quests = [_quest(
        id: 'q1',
        type: DailyQuestType.spendOnSelf,
        targetValue: 1500,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(
          amount: 500,
          category: '食費',
        ),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q1');
      expect(q.currentProgress, 0);
      expect(q.isCompleted, isFalse);
    });

    test('累積で目標超過すると完了する', () {
      final quests = [_quest(
        id: 'q1',
        type: DailyQuestType.spendOnSelf,
        targetValue: 1000,
        currentProgress: 600,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(
          amount: 500,
          category: '美容',
        ),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q1');
      expect(q.currentProgress, 1000);
      expect(q.isCompleted, isTrue);
      expect(q.dateCompleted, isNotNull);
    });

    test('複数回の支出で累積される', () {
      final quests = [_quest(
        id: 'q1',
        type: DailyQuestType.spendOnSelf,
        targetValue: 2000,
      )];
      var state = _state(quests);

      state = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 700, category: '趣味'),
      );
      state = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 800, category: '書籍'),
      );

      final q = state.quests.firstWhere((q) => q.id == 'q1');
      expect(q.currentProgress, 1500);
      expect(q.isCompleted, isFalse);
    });
  });

  // ─── receiptScan ──────────────────────────────────────

  group('receiptScan', () {
    test('レシート撮影で進捗+1', () {
      final quests = [_quest(
        id: 'q2',
        type: DailyQuestType.receiptScan,
        targetValue: 3,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.receiptScanned(),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q2');
      expect(q.currentProgress, 1);
      expect(q.isCompleted, isFalse);
    });

    test('必要枚数に達すると完了する', () {
      final quests = [_quest(
        id: 'q2',
        type: DailyQuestType.receiptScan,
        targetValue: 2,
        currentProgress: 1,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.receiptScanned(),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q2');
      expect(q.currentProgress, 2);
      expect(q.isCompleted, isTrue);
      expect(q.dateCompleted, isNotNull);
    });

    test('他タイプのクエストにレシート撮影は影響しない', () {
      final quests = [_quest(
        id: 'q3',
        type: DailyQuestType.spendOnSelf,
        targetValue: 1000,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.receiptScanned(),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q3');
      expect(q.currentProgress, 0);
    });
  });

  // ─── newCategory ──────────────────────────────────────

  group('newCategory', () {
    test('newCategoryUsed アクションで進捗+1', () {
      final quests = [_quest(
        id: 'q4',
        type: DailyQuestType.newCategory,
        targetValue: 1,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.newCategoryUsed(category: '医療費'),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q4');
      expect(q.currentProgress, 1);
      expect(q.isCompleted, isTrue);
      expect(q.dateCompleted, isNotNull);
    });

    test('支出記録アクションではnewCategoryは進捗しない'
        '（newCategoryUsed アクションでのみ検出）', () {
      final quests = [_quest(
        id: 'q4',
        type: DailyQuestType.newCategory,
        targetValue: 1,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(
          amount: 500,
          category: '教育費',
        ),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q4');
      expect(q.currentProgress, 0);
    });
  });

  // ─── underBudget ──────────────────────────────────────

  group('underBudget', () {
    test('支出額が累積進捗として記録される', () {
      final quests = [_quest(
        id: 'q5',
        type: DailyQuestType.underBudget,
        targetValue: 5000,
      )];
      final state = _state(quests);

      var updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 1200, category: '食費'),
      );
      updated = detector.detectAndUpdate(
        updated,
        action: const QuestAction.expenseRecorded(amount: 800, category: '交通費'),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q5');
      expect(q.currentProgress, 2000);
      expect(q.isCompleted, isFalse);
    });

    test('予算以内なら完了しない（underBudgetは予算超過しなければ成功）', () {
      // underBudgetの進捗は累積支出。目標値=予算額。
      // クエスト達成は「予算以内に収まった」こと。
      // ここでは進捗が目標値を超えない限りは進行中。
      // 達成判定は日跨ぎ時に行われる（DailyQuestOrchestrator側）
      final quests = [_quest(
        id: 'q5',
        type: DailyQuestType.underBudget,
        targetValue: 5000,
        currentProgress: 4000,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 500, category: '食費'),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q5');
      // 4500 < 5000 なので未完了
      expect(q.currentProgress, 4500);
      expect(q.isCompleted, isFalse);
    });

    test('予算超過した場合、進捗が目標値を超える', () {
      final quests = [_quest(
        id: 'q5',
        type: DailyQuestType.underBudget,
        targetValue: 5000,
        currentProgress: 4800,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 1000, category: '娯楽'),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q5');
      // currentProgress は updateProgress 内で targetValue にクランプされる
      expect(q.currentProgress, 5000);
      expect(q.isCompleted, isTrue);
    });
  });

  // ─── noSpending ──────────────────────────────────────

  group('noSpending', () {
    test('支出が発生したら失敗マークされる', () {
      final quests = [_quest(
        id: 'q6',
        type: DailyQuestType.noSpending,
        targetValue: 0,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 200, category: '食費'),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q6');
      expect(q.isFailed, isTrue);
      expect(q.isCompleted, isFalse);
    });

    test('支出がなければそのまま維持', () {
      final quests = [_quest(
        id: 'q6',
        type: DailyQuestType.noSpending,
        targetValue: 0,
      )];
      final state = _state(quests);

      // receiptScanは支出ではないので失敗しない
      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.receiptScanned(),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q6');
      expect(q.isFailed, isFalse);
      expect(q.isCompleted, isFalse);
    });
  });

  // ─── 複合シナリオ ──────────────────────────────────────

  group('複合シナリオ', () {
    test('複数クエストが同時に進捗する', () {
      final quests = [
        _quest(id: 'q1', type: DailyQuestType.spendOnSelf, targetValue: 1500),
        _quest(id: 'q5', type: DailyQuestType.underBudget, targetValue: 5000),
      ];
      final state = _state(quests);

      // 自己投資カテゴリの支出 → spendOnSelf と underBudget の両方に影響
      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(
          amount: 1000,
          category: '趣味',
        ),
      );

      final q1 = updated.quests.firstWhere((q) => q.id == 'q1');
      final q5 = updated.quests.firstWhere((q) => q.id == 'q5');
      expect(q1.currentProgress, 1000); // spendOnSelf: 趣味は自己投資
      expect(q5.currentProgress, 1000); // underBudget: 全支出カウント
    });

    test('支出が自己投資カテゴリでなければspendOnSelfは進捗しない', () {
      final quests = [
        _quest(id: 'q1', type: DailyQuestType.spendOnSelf, targetValue: 1500),
        _quest(id: 'q5', type: DailyQuestType.underBudget, targetValue: 5000),
      ];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(
          amount: 800,
          category: '食費',
        ),
      );

      final q1 = updated.quests.firstWhere((q) => q.id == 'q1');
      final q5 = updated.quests.firstWhere((q) => q.id == 'q5');
      expect(q1.currentProgress, 0);  // 食費は自己投資ではない
      expect(q5.currentProgress, 800); // underBudget: 全支出カウント
    });

    test('完了済みクエストは更新されない', () {
      final quests = [_quest(
        id: 'q1',
        type: DailyQuestType.spendOnSelf,
        targetValue: 1000,
        currentProgress: 1000,
        isCompleted: true,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 500, category: '書籍'),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q1');
      expect(q.currentProgress, 1000); // 変わらない
      expect(q.isCompleted, isTrue);
    });

    test('失敗済みクエストは更新されない', () {
      final quests = [_quest(
        id: 'q6',
        type: DailyQuestType.noSpending,
        targetValue: 0,
        isFailed: true,
      )];
      final state = _state(quests);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 200, category: '食費'),
      );

      final q = updated.quests.firstWhere((q) => q.id == 'q6');
      expect(q.isFailed, isTrue);
      expect(q.isCompleted, isFalse);
    });

    test('該当クエストがない場合は状態が変わらない', () {
      final state = DailyQuestState.empty();

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.expenseRecorded(amount: 500, category: '食費'),
      );

      expect(updated.quests, isEmpty);
    });

    test('questsが空でも例外が発生しない', () {
      final state = DailyQuestState(quests: []);

      final updated = detector.detectAndUpdate(
        state,
        action: const QuestAction.receiptScanned(),
      );

      expect(updated.quests, isEmpty);
    });
  });
}

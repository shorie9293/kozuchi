import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/tags/domain/models/tagged_transaction.dart';
import 'package:kozuchi/features/tags/domain/tag_aggregation_service.dart';
import 'package:kozuchi/features/tags/presentation/screens/tag_management_screen.dart';
import 'package:kozuchi/features/tags/presentation/screens/tag_summary_screen.dart';
import 'package:kozuchi/features/tags/presentation/tag_app_keys.dart';
import 'package:kozuchi/features/tags/presentation/widgets/tag_assignment_dialog.dart';

TransactionModel _tx({
  int amount = -1000,
  String purpose = 'ランチ',
  String datetime = '2026-09-12T12:00:00',
}) =>
    TransactionModel(
      amount: amount,
      purpose: purpose,
      category: '食費',
      datetime: datetime,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = TagRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TagManagementScreen', () {
    Widget build() => const MaterialApp(
          home: TagManagementScreen(repository: repository),
        );

    testWidgets('タイトルと空状態が表示される', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(find.text('タグ管理'), findsOneWidget);
      expect(find.text('タグがありません'), findsOneWidget);
    });

    testWidgets('タグを追加できる', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TagAppKeys.addButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(TagAppKeys.nameField), '旅行');
      await tester.tap(find.byKey(TagAppKeys.saveButton));
      await tester.pumpAndSettle();

      expect(find.text('旅行'), findsOneWidget);
      expect(find.text('タグがありません'), findsNothing);
      expect((await repository.loadTags()).single.name, '旅行');
    });

    testWidgets('空白のみでは追加されない', (tester) async {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TagAppKeys.addButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(TagAppKeys.nameField), '   ');
      await tester.tap(find.byKey(TagAppKeys.saveButton));
      await tester.pumpAndSettle();

      // ダイアログは開いたまま（pop されない）
      expect(find.byKey(TagAppKeys.nameField), findsOneWidget);
      expect(await repository.loadTags(), isEmpty);
    });

    testWidgets('既存タグを削除できる', (tester) async {
      await repository.createTag('旅行', id: 't1');
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TagAppKeys.deleteButton('t1')));
      await tester.pumpAndSettle();

      expect(find.text('旅行'), findsNothing);
      expect(await repository.loadTags(), isEmpty);
    });

    testWidgets('タグをタップして改名できる', (tester) async {
      await repository.createTag('旅行', id: 't1');
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TagAppKeys.listTile('t1')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(TagAppKeys.nameField),
        '国内旅行',
      );
      await tester.tap(find.byKey(TagAppKeys.saveButton));
      await tester.pumpAndSettle();

      expect(find.text('国内旅行'), findsOneWidget);
      expect((await repository.loadTags()).single.name, '国内旅行');
    });
  });

  group('TagSummaryScreen', () {
    testWidgets('タグ別の集計行とタグなし行を表示する', (tester) async {
      final tagged = _tx(amount: -1200, purpose: 'ランチ');
      final untagged = _tx(
        amount: -800,
        purpose: 'カフェ',
        datetime: '2026-09-12T15:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TagSummaryScreen(
            transactions: [tagged, untagged],
            tags: const [ExpenseTag(id: 't1', name: '旅行')],
            assignments: {
              TaggedTransaction.keyOfTransaction(tagged): const ['t1'],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('タグ別集計'), findsOneWidget);
      expect(find.byKey(TagAppKeys.summaryRow('t1')), findsOneWidget);
      expect(
        find.byKey(TagAppKeys.summaryUntaggedRow),
        findsOneWidget,
      );
      expect(find.textContaining('1件・支出 ¥1,200'), findsOneWidget);
      expect(find.textContaining('1件・支出 ¥800'), findsOneWidget);
    });

    testWidgets('取引が無い場合は空メッセージを表示する', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TagSummaryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('取引がありません'), findsOneWidget);
    });

    testWidgets('タグを選ぶと絞り込み件数が表示される', (tester) async {
      final t1 = _tx(amount: -1000, purpose: 'A');
      final t2 = _tx(
        amount: -2000,
        purpose: 'B',
        datetime: '2026-09-12T13:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TagSummaryScreen(
            transactions: [t1, t2],
            tags: const [ExpenseTag(id: 't1', name: '旅行')],
            assignments: {
              TaggedTransaction.keyOfTransaction(t1): const ['t1'],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TagAppKeys.summaryRow('t1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('選択中: 旅行 — 1件'), findsOneWidget);
      expect(find.text('絞り込みを解除'), findsOneWidget);
    });

    testWidgets('タグなし行を選ぶとタグ無し件数が表示される', (tester) async {
      final t1 = _tx(amount: -1000, purpose: 'A');

      await tester.pumpWidget(
        MaterialApp(
          home: TagSummaryScreen(
            transactions: [t1],
            tags: const [ExpenseTag(id: 't1', name: '旅行')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(TagAppKeys.summaryUntaggedRow));
      await tester.pumpAndSettle();

      expect(find.textContaining('— 1件'), findsWidgets);
    });
  });

  group('TagSummaryLoaderScreen', () {
    testWidgets('リポジトリからタグ定義と紐付けを読み込んで表示する', (tester) async {
      await repository.createTag('旅行', id: 't1');
      final tagged = _tx(amount: -1200, purpose: 'ランチ');
      await repository.assignTags(
        TaggedTransaction.keyOfTransaction(tagged),
        const ['t1'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TagSummaryLoaderScreen(
            transactions: [tagged],
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('タグ別集計'), findsOneWidget);
      expect(find.text('旅行'), findsOneWidget);
      expect(find.textContaining('1件・支出 ¥1,200'), findsOneWidget);
    });
  });

  group('showTagAssignmentDialog', () {
    testWidgets('選択されたタグIDを返す', (tester) async {
      List<String>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showTagAssignmentDialog(
                      context,
                      tags: const [
                        ExpenseTag(id: 't1', name: '旅行'),
                        ExpenseTag(id: 't2', name: 'サブスク'),
                      ],
                      selectedTagIds: const ['t1'],
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(TagAppKeys.assignmentDialog), findsOneWidget);

      // 既に選択済みの t1 を外し、t2 を選ぶ
      await tester.tap(find.text('旅行'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('サブスク'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(TagAppKeys.assignmentSaveButton),
      );
      await tester.pumpAndSettle();

      expect(result, ['t2']);
    });

    testWidgets('キャンセル時は null を返す', (tester) async {
      List<String>? result;
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showTagAssignmentDialog(
                      context,
                      tags: const [ExpenseTag(id: 't1', name: '旅行')],
                    );
                    called = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(result, isNull);
    });
  });

  group('集計サービスとの結合', () {
    test('集計結果の合計件数が取引件数と一致する', () {
      const service = TagAggregationService();
      final t1 = _tx(amount: -1000, purpose: 'A');
      final t2 = _tx(amount: -2000, purpose: 'B', datetime: '2026-09-13');

      final result = service.summarize(
        transactions: [t1, t2],
        assignments: {
          TaggedTransaction.keyOfTransaction(t1): const ['t1'],
        },
        tags: const [ExpenseTag(id: 't1', name: '旅行')],
      );

      final tagged = result.totals.fold<int>(0, (sum, t) => sum + t.count);
      expect(tagged + result.untaggedCount, 2);
    });
  });
}

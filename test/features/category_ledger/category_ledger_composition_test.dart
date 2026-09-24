import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/category_ledger/data/category_ledger_repository.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger_service.dart';
import 'package:kozuchi/features/category_ledger/presentation/category_ledger_app_keys.dart';
import 'package:kozuchi/features/category_ledger/presentation/screens/category_ledger_screen.dart';

/// 親（イシコリドメ）による探針。
///
/// 眷属の試練は「追加」「改名」「削除」を個別に撃ちがちで、
/// 画面→リポジトリ→再表示の合成や、改名が既存取引を壊さない不変条件を
/// 撃たない。ここではその合成の不変条件のみを撃つ。
ExpenseEntry _entry(String id, int amount, String category) => ExpenseEntry(
      id: id,
      amount: amount,
      category: category,
      date: DateTime(2026, 9, 20, 12),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// ListView の遅延描画対策として縦長のビューポートで描画する
  void widenViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required CategoryLedgerRepository repository,
    List<ExpenseEntry> entries = const [],
  }) async {
    widenViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryLedgerScreen(repository: repository, entries: entries),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('親探針: 画面 → リポジトリ → 再表示の合成', () {
    testWidgets('追加したカテゴリが永続化され、新しい画面インスタンスで復元される', (tester) async {
      final repo = InMemoryCategoryLedgerRepository();
      await pumpScreen(tester, repository: repo);

      // 追加操作
      await tester.tap(find.byKey(CategoryLedgerAppKeys.categoryLedger_addButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_nameField),
        'ペット費',
      );
      await tester.tap(find.byKey(CategoryLedgerAppKeys.categoryLedger_saveButton));
      await tester.pumpAndSettle();

      // 永続化層まで到達したか（画面の state だけ更新して保存を忘れる型を撃つ）
      expect(repo.stored, isNotNull, reason: 'saveLedger が呼ばれていない');
      expect(repo.stored!.categories, contains('ペット費'));
      expect(repo.stored!.categories.last, 'ペット費', reason: '追加は末尾のはず');

      // 再起動相当: 同じ永続化先を共有する別インスタンスで復元されるか
      await pumpScreen(tester, repository: repo);
      expect(find.byKey(CategoryLedgerAppKeys.row('ペット費')), findsOneWidget);
      expect(find.byKey(CategoryLedgerAppKeys.usage('ペット費')), findsOneWidget);
    });

    testWidgets('追加したカテゴリは台帳末尾の行として現れる（並び順の不変条件）', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費', 'その他']);
      await pumpScreen(tester, repository: repo);

      await tester.tap(find.byKey(CategoryLedgerAppKeys.categoryLedger_addButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_nameField),
        '推し活',
      );
      await tester.tap(find.byKey(CategoryLedgerAppKeys.categoryLedger_saveButton));
      await tester.pumpAndSettle();

      final rows = tester
          .widgetList<Card>(find.byType(Card))
          .toList();
      expect(rows.length, 4);
      expect(repo.stored!.categories, ['食費', '交通費', 'その他', '推し活']);
    });
  });

  group('親探針: 改名・削除が既存取引を壊さない', () {
    testWidgets('使用中カテゴリを改名すると旧名の取引は孤立カテゴリとして金額を保って残る',
        (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', 'ペット費', 'その他']);
      final entries = [
        _entry('e1', 1200, 'ペット費'),
        _entry('e2', 800, 'ペット費'),
        _entry('e3', 500, '食費'),
      ];
      await pumpScreen(tester, repository: repo, entries: entries);

      // 改名
      await tester.tap(find.byKey(CategoryLedgerAppKeys.menuButton('ペット費')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名前を変更'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_nameField),
        'ペット用品',
      );
      await tester.tap(find.byKey(CategoryLedgerAppKeys.categoryLedger_saveButton));
      await tester.pumpAndSettle();

      // 台帳は新名（順序も維持）
      expect(repo.stored!.categories, ['食費', 'ペット用品', 'その他']);

      // 旧名の取引は失われず、孤立カテゴリとして件数・金額を保つ
      final orphanUsage = tester.widget<Text>(
        find.byKey(CategoryLedgerAppKeys.usage('ペット費')),
      );
      expect(orphanUsage.data, '使用 2件 / ¥2000');
      expect(find.byKey(CategoryLedgerAppKeys.row('ペット用品')), findsOneWidget);
      expect(find.text('台帳に無いカテゴリ'), findsOneWidget);
    });

    testWidgets('カテゴリを削除しても取引は孤立カテゴリとして残り、最後の1件は削除できない',
        (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '娯楽']);
      final entries = [
        _entry('e1', 3000, '娯楽'),
      ];
      await pumpScreen(tester, repository: repo, entries: entries);

      await tester.tap(find.byKey(CategoryLedgerAppKeys.menuButton('娯楽')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      // 使用中である旨の警告が出る
      expect(find.textContaining('使用されています'), findsOneWidget);
      await tester.tap(find.byKey(CategoryLedgerAppKeys.deleteButton('娯楽')));
      await tester.pumpAndSettle();

      expect(repo.stored!.categories, ['食費']);
      expect(
        tester
            .widget<Text>(find.byKey(CategoryLedgerAppKeys.usage('娯楽')))
            .data,
        '使用 1件 / ¥3000',
      );

      // 最後の1件は削除できない（台帳が空にならない）
      await tester.tap(find.byKey(CategoryLedgerAppKeys.menuButton('食費')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CategoryLedgerAppKeys.deleteButton('食費')));
      await tester.pumpAndSettle();

      expect(repo.stored!.categories, ['食費']);
      expect(find.byKey(CategoryLedgerAppKeys.row('食費')), findsOneWidget);
      expect(find.text('最後のカテゴリは削除できません'), findsOneWidget);
    });
  });

  group('親探針: 外部由来カテゴリ名の正準化（自動分類と台帳の合成）', () {
    const service = CategoryLedgerService();

    test('分類辞書の「交通」は台帳の「交通費」へ寄る', () {
      final ledger = CategoryLedger.defaults();
      expect(service.resolveName(ledger, '交通'), '交通費');
    });

    test('完全一致はそのまま台帳の表記を返す', () {
      final ledger = CategoryLedger(['食費', 'ペット費']);
      expect(service.resolveName(ledger, '食費'), '食費');
      expect(service.resolveName(ledger, ' ペット費 '), 'ペット費');
    });

    test('台帳に無いカテゴリは null（勝手にカテゴリを増やさない）', () {
      final ledger = CategoryLedger(['食費', '交通費']);
      expect(service.resolveName(ledger, '推し活'), isNull);
      expect(service.resolveName(ledger, ''), isNull);
      expect(service.resolveName(ledger, '交通費'), '交通費');
    });

    test('台帳側が「交通」で辞書が「交通費」でも寄る', () {
      final ledger = CategoryLedger(['食費', '交通', 'その他']);
      expect(service.resolveName(ledger, '交通費'), '交通');
    });
  });
}

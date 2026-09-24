import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/category_ledger/data/category_ledger_repository.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';
import 'package:kozuchi/features/category_ledger/presentation/category_ledger_app_keys.dart';
import 'package:kozuchi/features/category_ledger/presentation/screens/category_ledger_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  late InMemoryCategoryLedgerRepository repository;

  Widget buildTestWidget({
    CategoryLedgerRepository? repo,
    List<ExpenseEntry>? entries,
  }) {
    return MaterialApp(
      home: CategoryLedgerScreen(
        repository: repo ?? repository,
        entries: entries,
      ),
    );
  }

  /// 画面を描画してロード完了まで進める
  Future<void> pumpScreen(
    WidgetTester tester, {
    CategoryLedgerRepository? repo,
    List<ExpenseEntry>? entries,
  }) async {
    await tester.pumpWidget(buildTestWidget(repo: repo, entries: entries));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('CategoryLedgerScreen 一覧表示', () {
    testWidgets('台帳のカテゴリ行が台帳順で全件表示される', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費', 'その他']);

      await pumpScreen(tester, repo: repo);

      expect(
        find.byKey(CategoryLedgerAppKeys.row('食費')),
        findsOneWidget,
      );
      expect(
        find.byKey(CategoryLedgerAppKeys.row('交通費')),
        findsOneWidget,
      );
      expect(
        find.byKey(CategoryLedgerAppKeys.row('その他')),
        findsOneWidget,
      );
    });

    testWidgets('各行に絵文字と使用実績が表示される', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', 'その他']);
      final entries = [
        ExpenseEntry(
          id: 'a',
          amount: 500,
          category: '食費',
          date: DateTime(2026, 9, 1),
        ),
        ExpenseEntry(
          id: 'b',
          amount: 300,
          category: '食費',
          date: DateTime(2026, 9, 2),
        ),
      ];

      await pumpScreen(tester, repo: repo, entries: entries);

      expect(find.text('使用 2件 / ¥800'), findsOneWidget);
      expect(find.text('使用 0件 / ¥0'), findsOneWidget);
      // 絵文字（食費は 🍙）
      expect(find.text('🍙'), findsOneWidget);
    });

    testWidgets('台帳に無いカテゴリの取引は孤立行として表示される', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費']);
      final entries = [
        ExpenseEntry(
          id: 'a',
          amount: 700,
          category: '娯楽',
          date: DateTime(2026, 9, 1),
        ),
      ];

      await pumpScreen(tester, repo: repo, entries: entries);

      expect(
        find.byKey(CategoryLedgerAppKeys.row('娯楽')),
        findsOneWidget,
      );
      expect(find.text('台帳に無いカテゴリ'), findsOneWidget);
    });
  });

  group('CategoryLedgerScreen 追加', () {
    testWidgets('正常系: 追加するとダイアログが閉じリポジトリに保存される', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費']);
      repository = repo;

      await pumpScreen(tester, repo: repo);

      await tester.tap(find.byKey(CategoryLedgerAppKeys.categoryLedger_addButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_nameField),
        '被服費',
      );
      await tester.tap(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_saveButton),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(CategoryLedgerAppKeys.categoryLedger_dialog),
          findsNothing);
      expect(find.byKey(CategoryLedgerAppKeys.row('被服費')), findsOneWidget);
      // リポジトリに保存されている
      final saved = await repo.loadLedger();
      expect(saved.contains('被服費'), isTrue);
    });

    testWidgets('重複エラー: 保存されずエラー文言が出る', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費']);
      repository = repo;

      await pumpScreen(tester, repo: repo);

      await tester.tap(find.byKey(CategoryLedgerAppKeys.categoryLedger_addButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_nameField),
        '食費',
      );
      await tester.tap(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_saveButton),
      );
      await tester.pump();

      expect(
        find.text('そのカテゴリ名は既に存在します'),
        findsOneWidget,
      );
      // ダイアログは閉じていない（保存されていない）
      expect(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_dialog),
        findsOneWidget,
      );
      final stored = await repo.loadLedger();
      expect(stored.length, 2);
    });

    testWidgets('空入力エラー: 保存されない', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費']);
      repository = repo;

      await pumpScreen(tester, repo: repo);

      await tester.tap(find.byKey(CategoryLedgerAppKeys.categoryLedger_addButton));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_saveButton),
      );
      await tester.pump();

      expect(find.text('カテゴリ名を入力してください'), findsOneWidget);
      final stored = await repo.loadLedger();
      expect(stored.length, 2);
    });
  });

  group('CategoryLedgerScreen 改名', () {
    testWidgets('メニューから改名すると台帳が更新される', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費']);
      repository = repo;

      await pumpScreen(tester, repo: repo);

      await tester.tap(find.byKey(CategoryLedgerAppKeys.menuButton('食費')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名前を変更'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_nameField),
        '伙食費',
      );
      await tester.tap(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_saveButton),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(CategoryLedgerAppKeys.row('伙食費')), findsOneWidget);
      expect(find.byKey(CategoryLedgerAppKeys.row('食費')), findsNothing);
      final saved = await repo.loadLedger();
      expect(saved.contains('伙食費'), isTrue);
      expect(saved.contains('食費'), isFalse);
    });
  });

  group('CategoryLedgerScreen 削除', () {
    testWidgets('確認ダイアログが開き、使用中カテゴリは警告文が表示される', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費']);
      repository = repo;
      final entries = [
        ExpenseEntry(
          id: 'a',
          amount: 500,
          category: '食費',
          date: DateTime(2026, 9, 1),
        ),
      ];

      await pumpScreen(tester, repo: repo, entries: entries);

      await tester.tap(find.byKey(CategoryLedgerAppKeys.menuButton('食費')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      expect(find.textContaining('件の取引で使用されています'), findsOneWidget);
      // 削除はキャンセルして閉じる
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.byKey(CategoryLedgerAppKeys.row('食費')), findsOneWidget);
    });

    testWidgets('削除を確定すると台帳から消えリポジトリに保存される', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger(['食費', '交通費']);
      repository = repo;

      await pumpScreen(tester, repo: repo);

      await tester.tap(find.byKey(CategoryLedgerAppKeys.menuButton('食費')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CategoryLedgerAppKeys.deleteButton('食費')));
      await tester.pumpAndSettle();

      expect(find.byKey(CategoryLedgerAppKeys.row('食費')), findsNothing);
      final saved = await repo.loadLedger();
      expect(saved.contains('食費'), isFalse);
    });
  });

  group('CategoryLedgerScreen リセット', () {
    testWidgets('リセットすると既定カテゴリに戻る', (tester) async {
      final repo = InMemoryCategoryLedgerRepository()
        ..stored = CategoryLedger([' Alpha']);
      repository = repo;

      await pumpScreen(tester, repo: repo);

      await tester.tap(
        find.byKey(CategoryLedgerAppKeys.categoryLedger_resetButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('リセット'));
      await tester.pumpAndSettle();

      final saved = await repo.loadLedger();
      expect(saved, CategoryLedger.defaults());
      // 既定カテゴリの行が表示されている
      expect(
        find.byKey(CategoryLedgerAppKeys.row('食費')),
        findsOneWidget,
      );
    });
  });
}
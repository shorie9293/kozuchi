import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/budget/data/closing_day_repository.dart';
import 'package:kozuchi/features/budget/presentation/budget_period_app_keys.dart';
import 'package:kozuchi/features/budget/presentation/widgets/budget_period_section.dart';

/// 実時計を使わない固定日付（時限爆弾回避）。
DateTime _fixed2026_11_01() => DateTime.utc(2026, 11, 1, 9).toLocal();

Future<void> _pumpSection(
  WidgetTester tester, {
  required ClosingDayRepository repository,
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BudgetPeriodSection(
            repository: repository,
            now: now ?? _fixed2026_11_01,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEditDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(BudgetPeriodAppKeys.editButton));
  await tester.pumpAndSettle();
}

/// ダイアログの Dropdown から締め日を選ぶ（メニューはスクロール可能）。
Future<void> _selectClosingDay(WidgetTester tester, int day) async {
  await tester.tap(find.byKey(BudgetPeriodAppKeys.dropdown));
  await tester.pumpAndSettle();

  final label = '毎月$day日締め';
  if (day != 1) {
    // メニューは ListView.builder で可視分のみ構築されるため、
    // 見つかるまでメニュー側の Scrollable をスクロールする。
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgetPeriodSection 表示', () {
    testWidgets('未保存時は「毎月末日締め」と暦月プレビューが表示される', (tester) async {
      final repository = InMemoryClosingDayRepository();
      await _pumpSection(tester, repository: repository);

      expect(find.text('家計の締め日'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.currentLabel)).data,
        '毎月末日締め',
      );
      expect(
        tester
            .widget<Text>(find.byKey(BudgetPeriodAppKeys.transitionLabel))
            .data,
        '暦月（1日〜末日）',
      );
      // now = 2026-11-01 / 締め日 1 → 2026/11/01 〜 2026/11/30（30日）
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.previewLabel)).data,
        '2026/11/01 〜 2026/11/30',
      );
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.previewDays)).data,
        '30日間',
      );
      expect(repository.stored, isNull);
    });

    testWidgets('25 が保存済なら「毎月25日締め」と前月26日〜当月25日のプレビュー', (tester) async {
      final repository = InMemoryClosingDayRepository()..stored = 25;
      await _pumpSection(tester, repository: repository);

      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.currentLabel)).data,
        '毎月25日締め',
      );
      expect(
        tester
            .widget<Text>(find.byKey(BudgetPeriodAppKeys.transitionLabel))
            .data,
        '前月26日〜当月25日',
      );
      // now = 2026-11-01（締め日以前）→ 前月26日〜当月25日
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.previewLabel)).data,
        '2026/10/26 〜 2026/11/25',
      );
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.previewDays)).data,
        '31日間',
      );
    });

    testWidgets('now 注入（2026-11-01 固定）で期間ラベルが決定論的に決まる', (tester) async {
      final repository = InMemoryClosingDayRepository()..stored = 25;
      var calls = 0;
      await _pumpSection(
        tester,
        repository: repository,
        now: () {
          calls++;
          return DateTime.utc(2026, 11, 1, 23, 30).toLocal();
        },
      );

      expect(calls, greaterThan(0));
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.previewLabel)).data,
        '2026/10/26 〜 2026/11/25',
      );
    });

    testWidgets('締め日を跨いだ日付では翌月締めの期間になる（now=2026-12-31）', (tester) async {
      final repository = InMemoryClosingDayRepository()..stored = 25;
      await _pumpSection(
        tester,
        repository: repository,
        now: () => DateTime.utc(2026, 12, 31, 12).toLocal(),
      );

      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.previewLabel)).data,
        '2026/12/26 〜 2027/01/25',
      );
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.previewDays)).data,
        '31日間',
      );
    });

    testWidgets('破損値（範囲外）が保存されていても 1 として表示される', (tester) async {
      final repository = InMemoryClosingDayRepository()..stored = 31;
      await _pumpSection(tester, repository: repository);

      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.currentLabel)).data,
        '毎月末日締め',
      );
    });
  });

  group('BudgetPeriodSection 変更ダイアログ', () {
    testWidgets('「変更」でダイアログが開き 1〜28 の選択肢を持つ', (tester) async {
      final repository = InMemoryClosingDayRepository();
      await _pumpSection(tester, repository: repository);

      await _openEditDialog(tester);

      expect(find.byKey(BudgetPeriodAppKeys.dropdown), findsOneWidget);
      expect(find.byKey(BudgetPeriodAppKeys.saveButton), findsOneWidget);
      expect(find.text('給与日などに合わせて、1ヶ月の区切りを選べます。'), findsOneWidget);

      final dropdown = tester.widget<DropdownButton<int>>(
        find.byKey(BudgetPeriodAppKeys.dropdown),
      );
      expect(dropdown.items?.length, 28);
      expect(dropdown.items?.first.value, 1);
      expect(dropdown.items?.last.value, 28);
    });

    testWidgets('25 を選んで保存すると repository に 25 が永続化され表示も更新される', (tester) async {
      final repository = InMemoryClosingDayRepository();
      await _pumpSection(tester, repository: repository);

      await _openEditDialog(tester);
      await _selectClosingDay(tester, 25);
      await tester.tap(find.byKey(BudgetPeriodAppKeys.saveButton));
      await tester.pumpAndSettle();

      // 保存まで到達していること（state だけ更新して保存しない実装は不可）
      expect(repository.stored, 25);

      // 保存後の再読込により表示が更新されていること
      expect(find.byKey(BudgetPeriodAppKeys.dropdown), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.currentLabel)).data,
        '毎月25日締め',
      );
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.previewLabel)).data,
        '2026/10/26 〜 2026/11/25',
      );
    });

    testWidgets('キャンセルでは保存されない', (tester) async {
      final repository = InMemoryClosingDayRepository();
      await _pumpSection(tester, repository: repository);

      await _openEditDialog(tester);
      await _selectClosingDay(tester, 25);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      expect(repository.stored, isNull);
      expect(
        tester.widget<Text>(find.byKey(BudgetPeriodAppKeys.currentLabel)).data,
        '毎月末日締め',
      );
    });
  });
}

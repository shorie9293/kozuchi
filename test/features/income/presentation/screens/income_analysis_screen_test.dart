import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/presentation/screens/income_analysis_screen.dart';
import 'package:kozuchi/features/income/presentation/widgets/income_analysis_keys.dart';

IncomeEntry _entry(String id, int amount, String source, DateTime date) =>
    IncomeEntry(id: id, amount: amount, source: source, date: date);

Future<void> _pump(
  WidgetTester tester, {
  List<IncomeEntry>? entries,
  List<IncomeEntry>? override,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IncomeAnalysisScreen(
        entries: entries ?? const [],
        entriesOverride: override,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final entries = [
    _entry('i1', 30000, '給与', DateTime(2026, 10, 1)),
    _entry('i2', 10000, '副業', DateTime(2026, 10, 5)),
    _entry('i3', 10000, '給与', DateTime(2026, 10, 10)),
    _entry('i4', 2000, '贈与', DateTime(2026, 10, 15)),
  ];

  testWidgets('収入源別の行が金額降順で表示され構成比・件数が出る', (tester) async {
    await _pump(tester, override: entries);

    // 合計カード
    expect(find.byKey(IncomeAnalysisAppKeys.totalCard), findsOneWidget);
    expect(find.text('合計 ¥52000・最多 給与'), findsOneWidget);

    // 収入源行: 給与40000 → 副業10000 → 贈与2000
    expect(
      find.byKey(IncomeAnalysisAppKeys.sourceRow('給与')),
      findsOneWidget,
    );
    expect(
      find.byKey(IncomeAnalysisAppKeys.sourceRow('副業')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(
        find.byKey(IncomeAnalysisAppKeys.sourceAmount('給与')),
      ).data,
      '¥40,000',
    );

    // 件数ラベル: 収入源3件・記録4件
    expect(find.text('収入源 3 件・記録 4 件'), findsOneWidget);
  });

  testWidgets('検索で絞り込み・クリアで復元される', (tester) async {
    await _pump(tester, override: entries);

    await tester.enterText(
      find.byKey(IncomeAnalysisAppKeys.searchField),
      '副業',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(IncomeAnalysisAppKeys.sourceRow('副業')), findsOneWidget);
    expect(find.byKey(IncomeAnalysisAppKeys.sourceRow('給与')), findsNothing);
    expect(find.text('収入源 1 件・記録 1 件'), findsOneWidget);

    // クリア
    await tester.tap(find.byKey(IncomeAnalysisAppKeys.searchClearButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(IncomeAnalysisAppKeys.sourceRow('給与')), findsOneWidget);
  });

  testWidgets('絞り込み結果が空なら「該当する収入源なし」', (tester) async {
    await _pump(tester, override: entries);

    await tester.enterText(
      find.byKey(IncomeAnalysisAppKeys.searchField),
      '存在しない',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('該当する収入源なし'), findsOneWidget);
    expect(find.byKey(IncomeAnalysisAppKeys.sourceRow('給与')), findsNothing);
  });

  testWidgets('記録が空なら空状態を表示する', (tester) async {
    await _pump(tester, override: const []);

    expect(find.byKey(IncomeAnalysisAppKeys.emptyState), findsOneWidget);
    expect(find.text('収入の記録はまだない'), findsOneWidget);
  });
}

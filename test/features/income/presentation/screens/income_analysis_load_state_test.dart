import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/load_state/load_state.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/presentation/screens/income_analysis_screen.dart';
import 'package:kozuchi/features/income/presentation/widgets/income_analysis_keys.dart';

IncomeEntry _entry(int amount, String source) => IncomeEntry(
      id: '$source-$amount',
      amount: amount,
      source: source,
      date: DateTime(2026, 10, 1),
    );

/// 呼出ごとに応答を切り替える loader（呼出回数を数える）。
class _ScriptedLoader {
  final List<LoadResult<List<IncomeEntry>>> script;
  int calls = 0;

  _ScriptedLoader(this.script);

  Future<LoadResult<List<IncomeEntry>>> call() async {
    final index = calls < script.length ? calls : script.length - 1;
    calls++;
    return script[index];
  }
}

Widget _wrap({required Future<LoadResult<List<IncomeEntry>>> Function() loader}) {
  return MaterialApp(home: IncomeAnalysisScreen(loader: loader));
}

void main() {
  group('IncomeAnalysisScreen - 読込局面の分離', () {
    testWidgets('失敗時は ErrorState を出し EmptyState を出さない', (tester) async {
      final loader = _ScriptedLoader([
        LoadResult<List<IncomeEntry>>.failure('収入の記録を読み込めませんでした'),
      ]);
      await tester.pumpWidget(_wrap(loader: loader.call));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
      expect(find.byKey(IncomeAnalysisAppKeys.emptyState), findsNothing);
      expect(find.text('収入の記録はまだない'), findsNothing);
      expect(find.text('収入の記録を読み込めませんでした'), findsOneWidget);
    });

    testWidgets('失敗時に素の「0円」表示が一切出ない', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loader: _ScriptedLoader([
            LoadResult<List<IncomeEntry>>.failure('収入の記録を読み込めませんでした'),
          ]).call,
        ),
      );
      await tester.pumpAndSettle();

      // 合計カード（¥0 を出す経路）が描画されていないこと
      expect(find.byKey(IncomeAnalysisAppKeys.totalCard), findsNothing);
      expect(find.textContaining('合計 ¥0'), findsNothing);
      expect(find.textContaining('¥0'), findsNothing);
    });

    testWidgets('空振り時は EmptyState を出し ErrorState を出さない', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loader: _ScriptedLoader([
            LoadResult<List<IncomeEntry>>.success(const <IncomeEntry>[]),
          ]).call,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.text('収入の記録はまだない'), findsOneWidget);
    });

    testWidgets('再試行タップでロードが2回目に入る（呼出回数 1→2）', (tester) async {
      final loader = _ScriptedLoader([
        LoadResult<List<IncomeEntry>>.failure('収入の記録を読み込めませんでした'),
        LoadResult<List<IncomeEntry>>.failure('まだ失敗'),
      ]);
      await tester.pumpWidget(_wrap(loader: loader.call));
      await tester.pumpAndSettle();
      expect(loader.calls, 1);

      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pumpAndSettle();

      expect(loader.calls, 2);
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
    });

    testWidgets('再試行の成功で ErrorState が消えデータ表示になる', (tester) async {
      final loader = _ScriptedLoader([
        LoadResult<List<IncomeEntry>>.failure('収入の記録を読み込めませんでした'),
        LoadResult<List<IncomeEntry>>.success([_entry(50000, '給与')]),
      ]);
      await tester.pumpWidget(_wrap(loader: loader.call));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.text('合計 ¥50000・最多 給与'), findsOneWidget);
    });

    testWidgets('成功時は ErrorState も EmptyState も出さない', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loader: _ScriptedLoader([
            LoadResult<List<IncomeEntry>>.success([_entry(30000, '給与')]),
          ]).call,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
      expect(find.text('収入源 1 件・記録 1 件'), findsOneWidget);
    });

    testWidgets('再読込の失敗で既存データを消さない', (tester) async {
      final loader = _ScriptedLoader([
        LoadResult<List<IncomeEntry>>.success([_entry(40000, '給与')]),
        LoadResult<List<IncomeEntry>>.failure('収入の記録を読み込めませんでした'),
      ]);
      await tester.pumpWidget(_wrap(loader: loader.call));
      await tester.pumpAndSettle();
      expect(find.text('合計 ¥40000・最多 給与'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('income_analysis_refresh')));
      await tester.pumpAndSettle();

      expect(loader.calls, 2);
      // 失敗バナーが出ても、取得済みデータは保持される
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.text('合計 ¥40000・最多 給与'), findsOneWidget);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
    });

    testWidgets('loader 未指定（従来モード）は entries をそのまま描画する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IncomeAnalysisScreen(entries: [_entry(20000, '副業')]),
        ),
      );
      await tester.pump();

      expect(find.byKey(IncomeAnalysisAppKeys.screen), findsOneWidget);
      expect(find.text('合計 ¥20000・最多 副業'), findsOneWidget);
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
    });

    testWidgets('従来モードの空状態文言は不変', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: IncomeAnalysisScreen()),
      );
      await tester.pump();

      expect(find.byKey(IncomeAnalysisAppKeys.emptyState), findsOneWidget);
      expect(find.text('収入の記録はまだない'), findsOneWidget);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
    });

    testWidgets('読込中はローディングを出し、データもエラーも出さない', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loader: () async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return LoadResult<List<IncomeEntry>>.success([_entry(1000, '給与')]);
          },
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('income_analysis_loading')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);

      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('income_analysis_loading')),
        findsNothing,
      );
    });
  });
}

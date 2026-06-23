import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart';

void main() {
  group('TransactionFilterBar', () {
    testWidgets('renders all filter controls', (tester) async {
      await tester.pumpWidget(_buildTestWidget());

      // 種別切替ボタン（SegmentedButton）が3つ表示される
      expect(find.text('全件'), findsOneWidget);
      expect(find.text('収入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);

      // 日付範囲フィールドが表示される
      expect(find.text('開始日'), findsOneWidget);
      expect(find.text('終了日'), findsOneWidget);
    });

    testWidgets('default filter values are shown', (tester) async {
      final initialFilter = TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 23),
      );

      await tester.pumpWidget(_buildTestWidget(initialFilter: initialFilter));

      // 日付が表示されること
      expect(find.text('2026-06-01'), findsOneWidget);
      expect(find.text('2026-06-23'), findsOneWidget);
    });

    testWidgets('emits filter on type change', (tester) async {
      TransactionFilter? emittedFilter;
      await tester.pumpWidget(_buildTestWidget(
        onChanged: (f) => emittedFilter = f,
      ));

      // 収入ボタンをタップ
      await tester.tap(find.text('収入'));
      await tester.pump();

      expect(emittedFilter, isNotNull);
      expect(emittedFilter!.type, TransactionFilterType.income);
    });

    testWidgets('emits filter on type change to expense', (tester) async {
      TransactionFilter? emittedFilter;
      await tester.pumpWidget(_buildTestWidget(
        onChanged: (f) => emittedFilter = f,
      ));

      await tester.tap(find.text('支出'));
      await tester.pump();

      expect(emittedFilter!.type, TransactionFilterType.expense);
    });

    testWidgets('tapping already selected type does not re-emit', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_buildTestWidget(
        onChanged: (_) => callCount++,
      ));

      // 全件はデフォルト選択。もう一度タップしても再emitされない
      await tester.tap(find.text('全件'));
      await tester.pump();

      expect(callCount, 0);
    });

    testWidgets('tapping start date field opens date picker', (tester) async {
      await tester.pumpWidget(_buildTestWidget());

      // 開始日フィールドをタップ
      await tester.tap(find.text('開始日').last);
      await tester.pumpAndSettle();

      // 日付ピッカーが表示される
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('tapping end date field opens date picker', (tester) async {
      await tester.pumpWidget(_buildTestWidget());

      await tester.tap(find.text('終了日').last);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}

/// テスト用ウィジェットラッパー
Widget _buildTestWidget({
  TransactionFilter initialFilter = const TransactionFilter(),
  void Function(TransactionFilter)? onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TransactionFilterBar(
        initialFilter: initialFilter,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
}

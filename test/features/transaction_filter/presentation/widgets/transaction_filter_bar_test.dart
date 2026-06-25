import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart';

void main() {
  group('TransactionFilterBar', () {
    /// Helper: pump TransactionFilterBar with initial filter and capture onChange.
    Future<void> pumpWidget(
      WidgetTester tester, {
      TransactionFilter initialFilter = const TransactionFilter(),
      ValueChanged<TransactionFilter>? onChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionFilterBar(
              initialFilter: initialFilter,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      );
    }

    // ── 基本表示 ──────────────────────────────────────────────

    testWidgets('種別トグル（全件/収入/支出）の3セグメントが表示される',
        (tester) async {
      await pumpWidget(tester);

      // 3つのセグメントラベルが表示される
      expect(find.text('全件'), findsOneWidget);
      expect(find.text('収入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
    });

    testWidgets('日付範囲チップ（開始日・終了日）が表示される',
        (tester) async {
      await pumpWidget(tester);

      // 日付範囲セクションがある
      expect(find.text('〜'), findsOneWidget);
    });

    testWidgets('日付指定ありの初期フィルタでは日付がYYYY-MM-DD形式で表示される',
        (tester) async {
      final filter = TransactionFilter(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 23),
      );

      await pumpWidget(tester, initialFilter: filter);

      expect(find.text('2026-06-01'), findsOneWidget);
      expect(find.text('2026-06-23'), findsOneWidget);
    });

    testWidgets('日付未指定の初期フィルタでは日付チップに ---- が表示される',
        (tester) async {
      await pumpWidget(tester);

      // 開始日と終了日の2つとも ---- が表示される
      expect(find.text('----'), findsNWidgets(2));
    });

    // ── フィルタ種別切替 ────────────────────────────────────────

    testWidgets('全件から収入に切り替えるとonChangedが発火する',
        (tester) async {
      TransactionFilter? emitted;
      await pumpWidget(
        tester,
        onChanged: (f) => emitted = f,
      );

      // 収入セグメントをタップ
      await tester.tap(find.text('収入'));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.type, TransactionFilterType.income);
    });

    testWidgets('全件から支出に切り替えるとonChangedが発火する',
        (tester) async {
      TransactionFilter? emitted;
      await pumpWidget(
        tester,
        onChanged: (f) => emitted = f,
      );

      // 支出セグメントをタップ
      await tester.tap(find.text('支出'));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.type, TransactionFilterType.expense);
    });

    testWidgets('収入初期状態から全件に切り替えられる',
        (tester) async {
      TransactionFilter? emitted;
      final initialFilter = const TransactionFilter(
        type: TransactionFilterType.income,
      );

      await pumpWidget(
        tester,
        initialFilter: initialFilter,
        onChanged: (f) => emitted = f,
      );

      // 全件セグメントをタップ
      await tester.tap(find.text('全件'));
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted!.type, TransactionFilterType.all);
    });

    testWidgets('同じ種別を再タップしてもonChangedは発火しない',
        (tester) async {
      int callCount = 0;
      await pumpWidget(
        tester,
        onChanged: (_) => callCount++,
      );

      // 全件（既に選択中）をタップ
      await tester.tap(find.text('全件'));
      await tester.pump();

      // 既に選択中のセグメントをタップしてもコールバックは呼ばれない
      expect(callCount, 0);
    });

    // ── 日付範囲選択 ────────────────────────────────────────

    testWidgets('開始日チップをタップするとDatePickerが開く',
        (tester) async {
      await pumpWidget(tester);

      // 開始日チップ（---- ラベルの1つ目）をタップ
      final dateChips = find.text('----');
      await tester.tap(dateChips.first);
      await tester.pumpAndSettle();

      // DatePickerが表示される
      expect(find.text('日付を選択'), findsOneWidget);
    });

    testWidgets('終了日チップをタップするとDatePickerが開く',
        (tester) async {
      await pumpWidget(tester);

      // 終了日チップ（---- ラベルの2つ目）をタップ
      final dateChips = find.text('----');
      await tester.tap(dateChips.last);
      await tester.pumpAndSettle();

      // DatePickerが表示される
      expect(find.text('日付を選択'), findsOneWidget);
    });

    // ── Semantics（アクセシビリティ） ─────────────────────────

    testWidgets('SegmentedButton（全件/収入/支出）が正しく描画される',
        (tester) async {
      await pumpWidget(tester);

      // SegmentedButtonの各セグメントが存在する
      expect(find.text('全件'), findsOneWidget);
      expect(find.text('収入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);

      // アイコンも表示されている
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    });

    // ── レスポンシブ ─────────────────────────────────────────

    testWidgets('狭い画面幅ではSegmentedButtonと日付範囲が縦に並ぶ',
        (tester) async {
      // 480px未満の幅でテスト
      tester.view.physicalSize = const Size(375, 800); // iPhoneサイズ
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpWidget(tester);

      // 種別トグルが表示されている
      expect(find.text('全件'), findsOneWidget);
      // 日付範囲も表示されている
      expect(find.text('〜'), findsOneWidget);
    });
  });
}

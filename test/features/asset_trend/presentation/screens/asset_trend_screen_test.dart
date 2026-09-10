import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/asset_trend/presentation/screens/asset_trend_screen.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

/// テスト用のモックコントローラ。全状態を自由に設定できる。
class _MockTransactionController extends TransactionController {
  final List<TransactionModel> _mockTransactions;
  final bool _mockIsLoading;
  final String? _mockError;
  int refetchCount = 0;

  _MockTransactionController({
    List<TransactionModel> transactions = const [],
    bool isLoading = false,
    String? error,
  })  : _mockTransactions = transactions,
        _mockIsLoading = isLoading,
        _mockError = error,
        super();

  @override
  List<TransactionModel> get transactions => List.unmodifiable(_mockTransactions);

  @override
  bool get isLoading => _mockIsLoading;

  @override
  String? get error => _mockError;

  @override
  Future<void> fetchTransactions() async {}

  @override
  Future<void> refetch() async {
    refetchCount++;
  }
}

TransactionModel _tx(int amount, String datetime) => TransactionModel(
      amount: amount,
      purpose: 'test',
      category: amount >= 0 ? '収入' : '支出',
      datetime: datetime,
    );

void main() {
  final now = DateTime(2026, 9, 15);

  Future<void> pumpScreen(
    WidgetTester tester,
    _MockTransactionController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AssetTrendScreen(controller: controller, now: now),
      ),
    );
  }

  group('AssetTrendScreen', () {
    testWidgets('AppBarに「資産推移」が表示される', (tester) async {
      await pumpScreen(tester, _MockTransactionController());
      expect(find.text('資産推移'), findsOneWidget);
    });

    testWidgets('ローディング中はインジケータを表示する', (tester) async {
      await pumpScreen(tester, _MockTransactionController(isLoading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('エラー時はメッセージと再試行ボタンを表示する', (tester) async {
      final controller = _MockTransactionController(error: 'ネットワークエラー');
      await pumpScreen(tester, controller);

      expect(find.text('ネットワークエラー'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);

      await tester.tap(find.text('再試行'));
      await tester.pump();
      expect(controller.refetchCount, 1);
    });

    testWidgets('データが空の場合はメッセージを表示する', (tester) async {
      await pumpScreen(tester, _MockTransactionController());
      expect(find.text('資産推移データがありません'), findsOneWidget);
    });

    testWidgets('取引データから累積残高グラフとサマリーを表示する', (tester) async {
      final controller = _MockTransactionController(
        transactions: [
          _tx(200000, '2026-07-05T10:00:00'),
          _tx(-50000, '2026-07-20T10:00:00'),
          _tx(-30000, '2026-08-10T10:00:00'),
          _tx(-20000, '2026-09-01T10:00:00'),
        ],
      );
      await pumpScreen(tester, controller);

      // サマリーカード（最新残高 100,000）
      expect(find.byKey(const Key('asset_trend_summary')), findsOneWidget);
      expect(find.text('¥100,000'), findsWidgets);
      // グラフ
      expect(find.byType(LineChart), findsOneWidget);
      // 月別ラベル（グラフ軸 + 月別リストの双方に表示される）
      expect(find.text('2026/07'), findsWidgets);
      expect(find.text('2026/09'), findsWidgets);
    });

    testWidgets('集計月数を変更すると期間が変わる', (tester) async {
      final controller = _MockTransactionController(
        transactions: [
          _tx(100000, '2026-07-01T10:00:00'),
          _tx(50000, '2026-09-01T10:00:00'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AssetTrendScreen(controller: controller, now: now, months: 2),
        ),
      );

      // 直近2ヶ月（8月・9月）に限定 → 7月は表示されない
      expect(find.text('2026/07'), findsNothing);
      expect(find.text('2026/09'), findsWidgets);
    });
  });
}

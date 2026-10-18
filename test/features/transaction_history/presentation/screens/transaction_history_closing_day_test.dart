import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

/// フィルタ更新を記録するだけのコントローラ（画面の配線だけを検証する）。
class _RecordingController extends TransactionController {
  _RecordingController({super.initialFilter})
      : _recorded = initialFilter ?? const TransactionFilter();

  TransactionFilter _recorded;

  /// updateFilter が呼ばれた回数（loader 未注入時の「何もしない」検証用）。
  int updateFilterCalls = 0;

  @override
  TransactionFilter get filter => _recorded;

  @override
  void updateFilter(TransactionFilter filter) {
    updateFilterCalls++;
    _recorded = filter;
    notifyListeners();
  }

  @override
  Future<void> fetchTransactions() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // SharedPreferences 未モックによる future 未完了ハングを避ける。
    SharedPreferences.setMockInitialValues({});
  });

  /// now は UTC 由来で構築（TZ=UTC でも緑）。
  DateTime clockDate() => DateTime.utc(2026, 11, 1, 12).toLocal();

  Future<_RecordingController> pumpPage(
    WidgetTester tester, {
    Future<int> Function()? closingDayLoader,
  }) async {
    final controller = _RecordingController();
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionHistoryPage(
          controller: controller,
          closingDayLoader: closingDayLoader,
          clock: clockDate,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  group('TransactionHistoryPage 締め日配線', () {
    testWidgets('closingDayLoader=25 で既定フィルタの開始日が 2026/10/26 になる', (tester) async {
      final controller = await pumpPage(
        tester,
        closingDayLoader: () async => 25,
      );

      final filter = controller.filter;
      expect(filter.startDate, DateTime(2026, 10, 26));
      // 終了日は従来どおり本日（now 注入値）
      expect(filter.endDate, DateTime(2026, 11, 1));
    });

    testWidgets('closingDayLoader=1 なら従来どおり月初（2026/11/01）', (tester) async {
      final controller = await pumpPage(
        tester,
        closingDayLoader: () async => 1,
      );

      expect(controller.filter.startDate, DateTime(2026, 11, 1));
    });

    testWidgets('closingDayLoader=null なら押し込まない（従来どおりの初期フィルタのまま）', (tester) async {
      final controller = await pumpPage(tester);

      // 注入コントローラの初期フィルタは画面が変更しない＝従来挙動
      expect(controller.updateFilterCalls, 0);
      expect(controller.filter.startDate, isNull);
    });

    testWidgets('closingDayLoader が例外でも既定（月初）に倒れる', (tester) async {
      final controller = await pumpPage(
        tester,
        closingDayLoader: () async => throw StateError('読み込み失敗'),
      );

      expect(controller.filter.startDate, DateTime(2026, 11, 1));
      expect(find.text('取引履歴'), findsOneWidget);
    });
  });
}

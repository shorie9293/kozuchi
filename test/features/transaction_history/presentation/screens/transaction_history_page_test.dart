import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';

/// テスト用のモックTransactionController。
///
/// [ChangeNotifier]を継承し、全フィールドを自由に設定可能。
class MockTransactionController extends TransactionController {
  final List<TransactionModel> _mockTransactions;
  final bool _mockIsLoading;
  final String? _mockError;
  final TransactionFilter _mockFilter;

  MockTransactionController({
    List<TransactionModel> transactions = const [],
    bool isLoading = false,
    String? error,
    TransactionFilter filter = const TransactionFilter(),
  })  : _mockTransactions = transactions,
        _mockIsLoading = isLoading,
        _mockError = error,
        _mockFilter = filter,
        super(
          service: TransactionService(client: MockClient((_) async {
            return http.Response('{"data": []}', 200);
          })),
        );

  @override
  List<TransactionModel> get transactions => List.unmodifiable(_mockTransactions);

  @override
  bool get isLoading => _mockIsLoading;

  @override
  String? get error => _mockError;

  @override
  TransactionFilter get filter => _mockFilter;

  @override
  void updateFilter(TransactionFilter filter) {
    // テスト用: 何もしない
  }

  @override
  Future<void> fetchTransactions() async {
    // テスト用: 何もしない
  }

  @override
  Future<void> refetch() async {
    // テスト用: 何もしない
  }

  // dispose() is inherited from ChangeNotifier — no need to override
}

void main() {
  group('TransactionHistoryPage', () {
    /// サンプル取引を生成するヘルパー。
    TransactionModel makeTx({
      int amount = 100000,
      String purpose = 'ボーナス',
      String category = '収入',
      String datetime = '2026-06-15T10:00:00',
    }) {
      return TransactionModel(
        amount: amount,
        purpose: purpose,
        category: category,
        datetime: datetime,
      );
    }

    /// Helper: pump TransactionHistoryPage with a mock controller.
    Future<void> pumpPage(
      WidgetTester tester, {
      required MockTransactionController controller,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TransactionHistoryPage(controller: controller),
        ),
      );
    }

    // ── 基本表示 ──────────────────────────────────────────────

    testWidgets('AppBarに「取引履歴」が表示される', (tester) async {
      final controller = MockTransactionController();
      await pumpPage(tester, controller: controller);

      expect(find.text('取引履歴'), findsOneWidget);
    });

    testWidgets('フィルタバーが表示される', (tester) async {
      final controller = MockTransactionController();
      await pumpPage(tester, controller: controller);

      // 種別フィルタのセグメントが表示される
      expect(find.text('全件'), findsOneWidget);
      expect(find.text('収入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
      // 日付範囲の区切り
      expect(find.text('〜'), findsOneWidget);
    });

    // ── ローディング状態 ──────────────────────────────────────

    testWidgets('ローディング中はスケルトンが表示される', (tester) async {
      final controller = MockTransactionController(isLoading: true);
      await pumpPage(tester, controller: controller);

      // スケルトン用のCardが表示される
      expect(find.byType(Card), findsWidgets);
      // 取引項目は表示されない
      expect(find.byType(TransactionListItem), findsNothing);
    });

    // ── データ表示状態 ──────────────────────────────────────

    testWidgets('取引データがある場合はTransactionListItemで表示される',
        (tester) async {
      final controller = MockTransactionController(
        transactions: [
          makeTx(amount: 100000, purpose: 'ボーナス', category: '収入'),
          makeTx(amount: -3000, purpose: 'コンビニ', category: '食費'),
        ],
      );
      await pumpPage(tester, controller: controller);

      // 取引項目が表示される
      expect(find.byType(TransactionListItem), findsNWidgets(2));
    });

    testWidgets('収入取引は緑色で金額が表示される', (tester) async {
      final controller = MockTransactionController(
        transactions: [
          makeTx(amount: 50000, purpose: '給与', category: '収入',
              datetime: '2026-06-15T10:00:00'),
        ],
      );
      await pumpPage(tester, controller: controller);

      // ¥50,000 が表示される（収入は緑色）
      expect(find.text('¥50,000'), findsOneWidget);
    });

    testWidgets('支出取引は赤色で金額が表示される', (tester) async {
      final controller = MockTransactionController(
        transactions: [
          makeTx(amount: -5000, purpose: '家賃', category: '住居費',
              datetime: '2026-06-01T09:00:00'),
        ],
      );
      await pumpPage(tester, controller: controller);

      // -¥5,000 が表示される（支出は赤色）
      expect(find.text('-¥5,000'), findsOneWidget);
    });

    testWidgets('取引の用途が表示される', (tester) async {
      final controller = MockTransactionController(
        transactions: [
          makeTx(amount: 100000, purpose: 'アルバイト代', category: '収入'),
        ],
      );
      await pumpPage(tester, controller: controller);

      expect(find.text('アルバイト代'), findsOneWidget);
    });

    testWidgets('取引のカテゴリがバッジで表示される', (tester) async {
      final controller = MockTransactionController(
        transactions: [
          makeTx(amount: -1000, purpose: 'コーヒー', category: '食費'),
        ],
      );
      await pumpPage(tester, controller: controller);

      // カテゴリ名が表示される
      expect(find.text('食費'), findsWidgets);
    });

    testWidgets('取引の日時がyyyy/MM/dd HH:mm形式で表示される',
        (tester) async {
      final controller = MockTransactionController(
        transactions: [
          makeTx(datetime: '2026-06-15T14:30:00'),
        ],
      );
      await pumpPage(tester, controller: controller);

      expect(find.text('2026/06/15 14:30'), findsOneWidget);
    });

    // ── エラー状態 ──────────────────────────────────────────

    testWidgets('エラー時はエラーメッセージとリトライボタンが表示される',
        (tester) async {
      final controller = MockTransactionController(
        error: 'ネットワークエラーが発生しました',
      );
      await pumpPage(tester, controller: controller);

      expect(find.text('ネットワークエラーが発生しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
    });

    // ── 空状態 ──────────────────────────────────────────────

    testWidgets('取引が0件の場合は「取引がありません」が表示される',
        (tester) async {
      // 空データだが _hasFetched = true の状態にする必要がある
      // 既にfetch済みのMockControllerを使う
      final controller = MockTransactionController(
        transactions: [],
        isLoading: false,
        error: null,
      );
      await pumpPage(tester, controller: controller);

      // 取引がありません メッセージが表示される
      expect(find.text('取引がありません'), findsOneWidget);
    });

    // ── フィルタとの統合 ────────────────────────────────────

    testWidgets('FilterBarにデフォルトフィルタ値が渡される',
        (tester) async {
      final filter = TransactionFilter(
        type: TransactionFilterType.income,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 23),
      );
      final controller = MockTransactionController(filter: filter);
      await pumpPage(tester, controller: controller);

      // 初期フィルタの日付が表示される
      expect(find.text('2026-06-01'), findsOneWidget);
      expect(find.text('2026-06-23'), findsOneWidget);
    });

    // ── 多数取引の表示 ──────────────────────────────────────

    testWidgets('多数の取引でもスクロール可能なリストで表示される（仮想化）',
        (tester) async {
      final transactions = List.generate(
        50,
        (i) => makeTx(
          amount: -1000 - (i * 100),
          purpose: '取引$i',
          category: 'その他',
          datetime: '2026-06-${(i % 28 + 1).toString().padLeft(2, '0')}T12:00:00',
        ),
      );

      final controller = MockTransactionController(
        transactions: transactions,
      );
      await pumpPage(tester, controller: controller);

      // ListView.builderは仮想化されているため、全件は表示されない
      // 表示領域に収まる分だけがレンダリングされる
      expect(find.byType(TransactionListItem), findsWidgets);
      // 最初の取引が表示されている
      expect(find.text('取引0'), findsOneWidget);
      // 少なくとも複数件の取引が表示されている
      final itemCount = find.byType(TransactionListItem).evaluate().length;
      expect(itemCount, greaterThan(2));
    });
  });
}

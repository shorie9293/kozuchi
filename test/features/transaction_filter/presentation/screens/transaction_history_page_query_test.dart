import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_filter/presentation/transaction_query_app_keys.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';

/// 試練用のフェイク TagRepository（実 SharedPreferences / Supabase には触れない）。
class FakeTagRepository implements TagRepository {
  FakeTagRepository({
    this.tags = const [],
    this.assignments = const {},
  });

  List<ExpenseTag> tags;
  Map<String, List<String>> assignments;

  @override
  Future<List<ExpenseTag>> loadTags() async => tags;

  @override
  Future<Map<String, List<String>>> loadAssignments() async => assignments;

  @override
  Future<List<ExpenseTag>> saveTags(List<ExpenseTag> tags) async {
    this.tags = tags;
    return tags;
  }

  @override
  Future<List<ExpenseTag>> createTag(String name,
      {String? id, int? colorValue}) async {
    final tag = ExpenseTag(id: id ?? 'new', name: name);
    tags = [...tags, tag];
    return tags;
  }

  @override
  Future<List<ExpenseTag>> renameTag(String id, String name) async => tags;

  @override
  Future<List<ExpenseTag>> deleteTag(String id) async {
    tags = tags.where((t) => t.id != id).toList();
    return tags;
  }

  @override
  Future<void> saveAssignments(Map<String, List<String>> assignments) async {
    this.assignments = assignments;
  }

  @override
  Future<List<String>> tagsFor(String transactionKey) async =>
      assignments[transactionKey] ?? const [];

  @override
  Future<Map<String, List<String>>> assignTags(
    String transactionKey,
    List<String> tagIds,
  ) async {
    assignments = {...assignments, transactionKey: tagIds};
    return assignments;
  }
}

void main() {
  group('TransactionHistoryPage（キーワード・カテゴリ・タグ検索の配線）', () {
    /// 当月のタイムスタンプ（デフォルトフィルタ = 当月1日〜本日 に含まれる）。
    final String nowTs = () {
      final n = DateTime.now();
      final d = n.day.toString().padLeft(2, '0');
      final h = n.hour.toString().padLeft(2, '0');
      final m = n.minute.toString().padLeft(2, '0');
      return '${n.year}-${n.month.toString().padLeft(2, '0')}-${d}T$h:$m:00';
    }();

    TransactionModel makeTx({
      int amount = -1000,
      String purpose = 'コンビニ',
      String category = '食費',
      String? datetime,
    }) {
      return TransactionModel(
        amount: amount,
        purpose: purpose,
        category: category,
        datetime: datetime ?? nowTs,
      );
    }

    /// Helper: pump the page with a fake controller + fake tag repository.
    Future<void> pumpPage(
      WidgetTester tester, {
      required MockQueryController controller,
      FakeTagRepository? tagRepository,
      Size? physicalSize,
    }) async {
      tester.view.physicalSize = physicalSize ?? const Size(1080, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: TransactionHistoryPage(
            controller: controller,
            tagRepository: tagRepository ?? FakeTagRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('サマリーバーに全取引の件数・収入合計・支出合計が表示される',
        (tester) async {
      final controller = MockQueryController(
        transactions: [
          makeTx(amount: 3000, purpose: '賞与', category: '収入',
              datetime: '2026-06-10T10:00:00'),
          makeTx(amount: -8400, purpose: 'スーパー', category: '食費',
              datetime: '2026-06-11T10:00:00'),
          makeTx(amount: -500, purpose: '缶コーヒー', category: '食費',
              datetime: '2026-06-12T10:00:00'),
        ],
      );
      await pumpPage(tester, controller: controller);

      expect(find.byKey(TransactionQueryAppKeys.summaryBar), findsOneWidget);
      expect(
        find.text('3件 / 収入 ¥3,000 / 支出 ¥8,900'),
        findsOneWidget,
      );
    });

    testWidgets('キーワード入力で絞り込まれ、行が減りサマリーも変わる', (tester) async {
      final controller = MockQueryController(
        transactions: [
          makeTx(amount: -8400, purpose: 'スーパー', category: '食費',
              datetime: '2026-06-11T10:00:00'),
          makeTx(amount: -500, purpose: '缶コーヒー', category: '食費',
              datetime: '2026-06-12T10:00:00'),
        ],
      );
      await pumpPage(tester, controller: controller);

      expect(find.byType(TransactionListItem), findsNWidgets(2));

      await tester.enterText(
        find.byKey(TransactionQueryAppKeys.keywordField),
        'スーパー',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TransactionListItem), findsNWidgets(1));
      expect(find.text('スーパー'), findsWidgets);
      expect(
        find.text('1件 / 収入 ¥0 / 支出 ¥8,400'),
        findsOneWidget,
      );
    });

    testWidgets('カテゴリチップ選択で絞り込まれる', (tester) async {
      final controller = MockQueryController(
        transactions: [
          makeTx(amount: -8400, purpose: 'スーパー', category: '食費',
              datetime: '2026-06-11T10:00:00'),
          makeTx(amount: -10000, purpose: '映画', category: '娯楽',
              datetime: '2026-06-12T10:00:00'),
        ],
      );
      await pumpPage(tester, controller: controller);

      await tester.tap(
        find.byKey(TransactionQueryAppKeys.categoryChip('娯楽')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TransactionListItem), findsNWidgets(1));
      expect(find.text('映画'), findsWidgets);
    });

    testWidgets('タグチップ選択でタグ紐付けに基づき絞り込まれる', (tester) async {
      final tx1 = makeTx(amount: -8400, purpose: 'スーパー', category: '食費',
          datetime: '2026-06-11T10:00:00');
      final tx2 = makeTx(amount: -500, purpose: '缶コーヒー', category: '食費',
          datetime: '2026-06-12T10:00:00');

      final controller = MockQueryController(transactions: [tx1, tx2]);
      final tagRepository = FakeTagRepository(
        tags: const [ExpenseTag(id: 't1', name: '旅行')],
        assignments: {
          '2026-06-11T10:00:00|-8400|スーパー|食費': ['t1'],
        },
      );
      await pumpPage(tester, controller: controller, tagRepository: tagRepository);

      await tester.tap(find.byKey(TransactionQueryAppKeys.tagChip('t1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TransactionListItem), findsNWidgets(1));
      expect(find.text('スーパー'), findsWidgets);
    });

    testWidgets('0件時は空状態文言がサマリーに表示される', (tester) async {
      final controller = MockQueryController(
        transactions: [
          makeTx(amount: -1000, purpose: 'コンビニ', category: '食費'),
        ],
      );
      await pumpPage(tester, controller: controller);

      await tester.enterText(
        find.byKey(TransactionQueryAppKeys.keywordField),
        '存在しないキーワード',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('該当する取引がありません'), findsOneWidget);
      expect(find.byType(TransactionListItem), findsNothing);
    });

    testWidgets('タグ定義を読み込みフィルタバーにタグチップを渡す', (tester) async {
      final controller = MockQueryController(
        transactions: [makeTx()],
      );
      final tagRepository = FakeTagRepository(
        tags: const [
          ExpenseTag(id: 't1', name: '旅行'),
          ExpenseTag(id: 't2', name: 'サブスク'),
        ],
      );
      await pumpPage(tester, controller: controller, tagRepository: tagRepository);

      expect(find.text('旅行'), findsOneWidget);
      expect(find.text('サブスク'), findsOneWidget);
    });

    testWidgets('タグ読み込みが失敗しても空でフォールバックし画面が表示される', (tester) async {
      final controller = MockQueryController(transactions: [makeTx()]);
      final tagRepository = _ThrowingTagRepository();
      await pumpPage(tester, controller: controller, tagRepository: tagRepository);

      // タグチップは出ないが画面は壊れない
      expect(find.text('旅行'), findsNothing);
      expect(find.text('取引履歴'), findsOneWidget);
    });

    testWidgets('リセットボタンでフィルタが初期状態に戻る', (tester) async {
      final controller = MockQueryController(
        transactions: [makeTx(amount: -1000, purpose: 'コンビニ')],
      );
      await pumpPage(tester, controller: controller);

      await tester.enterText(
        find.byKey(TransactionQueryAppKeys.keywordField),
        '存在しない',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('該当する取引がありません'), findsOneWidget);

      await tester.tap(find.byKey(TransactionQueryAppKeys.resetButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // リセット後は再び行が表示される
      expect(find.byType(TransactionListItem), findsOneWidget);
    });
  });
}

/// タグ読み込みが常に失敗するフェイクリポジトリ。
class _ThrowingTagRepository extends FakeTagRepository {
  @override
  Future<List<ExpenseTag>> loadTags() async {
    throw Exception('load failed');
  }

  @override
  Future<Map<String, List<String>>> loadAssignments() async {
    throw Exception('load failed');
  }
}

/// 検索配線試練用のモック TransactionController。
///
/// 既存テストの MockTransactionController と同じく、全ゲッターを差し替え可能にする。
class MockQueryController extends TransactionController {
  MockQueryController({
    List<TransactionModel> transactions = const [],
    TransactionFilter filter = const TransactionFilter(),
  })  : _mockTransactions = transactions,
        _mockFilter = filter,
        super(
          service: TransactionService(
            client: MockClient((_) async => http.Response('{"data": []}', 200)),
          ),
        );

  List<TransactionModel> _mockTransactions;
  TransactionFilter _mockFilter;

  @override
  List<TransactionModel> get transactions =>
      List.unmodifiable(_mockTransactions);

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  TransactionFilter get filter => _mockFilter;

  @override
  void updateFilter(TransactionFilter filter) {
    // ページ側の ListenableBuilder が再計算するよう通知する
    _mockFilter = filter;
    notifyListeners();
  }

  @override
  Future<void> fetchTransactions() async {}

  @override
  Future<void> refetch() async {}
}

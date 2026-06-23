import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_item.dart';
import 'package:kozuchi/features/transaction_history/presentation/widgets/transaction_list_widget.dart';

void main() {
  group('TransactionListWidget', () {
    /// Helper: pump TransactionListWidget with given props.
    Future<void> pumpWidget(
      WidgetTester tester, {
      List<TransactionModel> transactions = const [],
      bool isLoading = false,
      String? errorMessage,
      VoidCallback? onRetry,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionListWidget(
              transactions: transactions,
              isLoading: isLoading,
              errorMessage: errorMessage,
              onRetry: onRetry,
            ),
          ),
        ),
      );
    }

    /// サンプル取引を生成するヘルパー。
    TransactionModel makeTx({
      int amount = 1000,
      String purpose = '食費',
      String category = '食費',
      String datetime = '2026-06-23T12:00:00',
    }) {
      return TransactionModel(
        amount: amount,
        purpose: purpose,
        category: category,
        datetime: datetime,
      );
    }

    // ── ローディング状態 ──────────────────────────────────────────

    testWidgets('isLoading=true のときスケルトンが表示される', (tester) async {
      await pumpWidget(tester, isLoading: true);

      // スケルトン用の Card が5件表示される（灰色のContainer群）
      expect(find.byType(Card), findsNWidgets(5));
      // 取引項目は表示されない
      expect(find.byType(TransactionListItem), findsNothing);
      // 空メッセージも表示されない
      expect(find.text('取引がありません'), findsNothing);
    });

    testWidgets('isLoading=true は transactions より優先される', (tester) async {
      // 取引データがあってもローディング表示が優先
      await pumpWidget(
        tester,
        isLoading: true,
        transactions: [makeTx()],
      );

      expect(find.byType(Card), findsNWidgets(5));
      expect(find.byType(TransactionListItem), findsNothing);
    });

    // ── 空リスト状態 ─────────────────────────────────────────────

    testWidgets('空リストのとき「取引がありません」が表示される', (tester) async {
      await pumpWidget(tester);

      expect(find.text('取引がありません'), findsOneWidget);
      // レシートアイコンも表示
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      // リスト項目は無し
      expect(find.byType(TransactionListItem), findsNothing);
    });

    testWidgets('空リスト表示は isAfterLoad 完了後にのみ表示', (tester) async {
      // isLoading=false かつ errorMessage=null かつ transactions=[] のとき表示
      await pumpWidget(tester, transactions: []);

      expect(find.text('取引がありません'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    // ── エラー状態 ───────────────────────────────────────────────

    testWidgets('エラーメッセージとリトライボタンが表示される', (tester) async {
      bool retryCalled = false;
      await pumpWidget(
        tester,
        errorMessage: 'ネットワークエラーが発生しました',
        onRetry: () => retryCalled = true,
      );

      // エラーメッセージが表示される
      expect(find.text('ネットワークエラーが発生しました'), findsOneWidget);
      // エラーアイコン
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // リトライボタン
      expect(find.text('再試行'), findsOneWidget);

      // リトライボタンをタップすると onRetry が呼ばれる
      await tester.tap(find.text('再試行'));
      expect(retryCalled, isTrue);
    });

    testWidgets('onRetry が null のときリトライボタンは非表示', (tester) async {
      await pumpWidget(
        tester,
        errorMessage: 'エラー',
        onRetry: null,
      );

      expect(find.text('エラー'), findsOneWidget);
      // リトライボタンは無し
      expect(find.text('再試行'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('エラー表示は transactions より優先される', (tester) async {
      await pumpWidget(
        tester,
        errorMessage: 'データ取得失敗',
        onRetry: () {},
        transactions: [makeTx(), makeTx()],
      );

      // エラーメッセージが表示され、取引リストは出ない
      expect(find.text('データ取得失敗'), findsOneWidget);
      expect(find.byType(TransactionListItem), findsNothing);
    });

    testWidgets('エラー表示は isLoading より劣後する', (tester) async {
      // isLoading=true のときはローディングが最も優先
      await pumpWidget(
        tester,
        isLoading: true,
        errorMessage: 'エラー',
        onRetry: () {},
      );

      // スケルトンが表示され、エラーは出ない
      expect(find.byType(Card), findsNWidgets(5));
      expect(find.text('エラー'), findsNothing);
    });

    // ── 通常リスト表示 ───────────────────────────────────────────

    testWidgets('取引リストが TransactionListItem で表示される', (tester) async {
      final txs = [
        makeTx(amount: 50000, purpose: '給与', category: '収入'),
        makeTx(amount: -3000, purpose: '食費', category: '食費'),
      ];

      await pumpWidget(tester, transactions: txs);

      // 2件の TransactionListItem が表示される
      expect(find.byType(TransactionListItem), findsNWidgets(2));
      // 金額が表示される
      expect(find.text('¥50,000'), findsOneWidget);
      expect(find.text('-¥3,000'), findsOneWidget);
      // 用途
      expect(find.text('給与'), findsOneWidget);
      expect(find.text('食費'), findsAtLeast(1)); // 用途＋カテゴリで2回表示されうる
    });

    testWidgets('多数アイテムでも ListView.builder で効率的に表示', (tester) async {
      // 100件の取引を生成
      final txs = List.generate(100, (i) {
        return makeTx(
          amount: 1000 + i,
          purpose: '取引$i',
          category: 'その他',
          datetime: '2026-06-23T${i ~/ 60}:${i % 60}:00',
        );
      });

      await pumpWidget(tester, transactions: txs);

      // TransactionListItem が生成されている（ListView.builder により
      // 画面上に見える分だけが実際にビルドされる）
      final items = tester.widgetList(find.byType(TransactionListItem));
      expect(items.length, greaterThan(0));

      // 先頭の項目は表示される
      expect(find.text('¥1,000'), findsOneWidget);
      expect(find.text('取引0'), findsOneWidget);
    });

    testWidgets('単一の取引も正しく表示される', (tester) async {
      await pumpWidget(
        tester,
        transactions: [makeTx(purpose: '単独テスト', category: 'テスト')],
      );

      expect(find.byType(TransactionListItem), findsOneWidget);
      expect(find.text('単独テスト'), findsOneWidget);
      expect(find.text('テスト'), findsOneWidget);
    });
  });
}

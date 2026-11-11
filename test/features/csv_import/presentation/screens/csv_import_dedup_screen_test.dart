import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/csv_import/domain/csv_import_service.dart';
import 'package:kozuchi/features/csv_import/presentation/screens/csv_import_screen.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';

/// 既存取引を読めない（照合不能な）リポジトリ
class _UnverifiableRepository extends LocalTransactionRepository {
  _UnverifiableRepository();

  @override
  Future<TransactionLoadOutcome> loadAllForVerification() async {
    return const TransactionLoadOutcome(
      transactions: <TransactionModel>[],
      verified: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const csvTwo = 'date,desc,amount\n'
      '2026-06-01,給与,+300000\n'
      '2026-06-02,食費,-1200\n';

  /// 既存2件 + 新規1件（重複が発生するCSV）
  const csvThree = 'date,desc,amount\n'
      '2026-06-01,給与,+300000\n'
      '2026-06-02,食費,-1200\n'
      '2026-06-03,交通費,-800\n';

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Future<String?> Function() pickCsvContent,
    CsvImportService? service,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CsvImportScreen(
          service: service,
          pickCsvContent: pickCsvContent,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 既存取引として2件を保存する
  Future<void> seedTwoTransactions() async {
    await const CsvImportService().importCsv(csvTwo);
  }

  Future<int> savedCount() async {
    final saved = await const LocalTransactionRepository().loadAll();
    return saved.length;
  }

  group('CsvImportScreen 重複スキップ', () {
    testWidgets('重複0件ならpick1回で従来通り即時取込される', (tester) async {
      await pumpScreen(tester, pickCsvContent: () async => csvTwo);

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();

      // 確認カードは出ず、結果カードだけが出る
      expect(find.byKey(KozuchiAppKeys.csvImport_previewCard), findsNothing);
      expect(find.byKey(KozuchiAppKeys.csvImport_resultCard), findsOneWidget);
      expect(find.textContaining('2件'), findsWidgets);
      expect(await savedCount(), 2);
    });

    testWidgets('重複ありならpick後にプレビューが出てまだ永続化されない', (tester) async {
      await seedTwoTransactions();
      await pumpScreen(tester, pickCsvContent: () async => csvThree);

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();

      expect(find.byKey(KozuchiAppKeys.csvImport_previewCard), findsOneWidget);
      expect(find.byKey(KozuchiAppKeys.csvImport_freshCountText), findsOneWidget);
      expect(find.text('新規 1件'), findsOneWidget);
      expect(find.text('重複 2件'), findsOneWidget);
      // 確認前なので保存件数は増えていない
      expect(await savedCount(), 2);
    });

    testWidgets('主ボタンで重複をスキップして取り込む', (tester) async {
      await seedTwoTransactions();
      await pumpScreen(tester, pickCsvContent: () async => csvThree);

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_confirmButton));
      await tester.pumpAndSettle();

      expect(find.byKey(KozuchiAppKeys.csvImport_previewCard), findsNothing);
      expect(find.text('重複スキップ: 2件'), findsOneWidget);
      expect(await savedCount(), 3);

      final saved = await const LocalTransactionRepository().loadAll();
      expect(saved.last.purpose, '交通費');
    });

    testWidgets('「重複も取り込む」をONにすると重複も書き込まれる', (tester) async {
      await seedTwoTransactions();
      await pumpScreen(tester, pickCsvContent: () async => csvThree);

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(KozuchiAppKeys.csvImport_includeDuplicatesSwitch),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_confirmButton));
      await tester.pumpAndSettle();

      expect(await savedCount(), 5);
      expect(find.textContaining('3件'), findsWidgets);
    });

    testWidgets('照合不能なら警告を出し主ボタンでは書き込まない', (tester) async {
      final service = CsvImportService(
        repository: _UnverifiableRepository(),
      );
      await pumpScreen(
        tester,
        service: service,
        pickCsvContent: () async => csvTwo,
      );

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();

      expect(find.byKey(KozuchiAppKeys.csvImport_previewCard), findsOneWidget);
      expect(
        find.byKey(KozuchiAppKeys.csvImport_unverifiedNotice),
        findsOneWidget,
      );
      expect(find.text('重複確認ができませんでした'), findsOneWidget);
      // 内訳は出さない
      expect(find.byKey(KozuchiAppKeys.csvImport_freshCountText), findsNothing);
      expect(
        find.byKey(KozuchiAppKeys.csvImport_duplicateCountText),
        findsNothing,
      );
      // まだ何も書き込まれていない
      expect(await savedCount(), 0);

      // 照合不能時は主ボタンを押せない（押せるとプレビューが消費され
      // 上書き導線へ辿れなくなるため、親探針が検出して無効化した）
      final confirm = tester.widget<ElevatedButton>(
        find.byKey(KozuchiAppKeys.csvImport_confirmButton),
      );
      expect(confirm.onPressed, isNull);
      expect(await savedCount(), 0);
      // 上書き導線は引き続き生きている
      expect(
        find.byKey(KozuchiAppKeys.csvImport_unverifiedOverrideButton),
        findsOneWidget,
      );
    });

    testWidgets('照合不能でも上書きボタンで取り込める', (tester) async {
      final service = CsvImportService(
        repository: _UnverifiableRepository(),
      );
      await pumpScreen(
        tester,
        service: service,
        pickCsvContent: () async => csvTwo,
      );

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(KozuchiAppKeys.csvImport_unverifiedOverrideButton),
      );
      await tester.pumpAndSettle();

      expect(await savedCount(), 2);
      expect(find.text('重複確認なしで取り込みました'), findsOneWidget);
    });

    testWidgets('キャンセルすると何も書き込まれない', (tester) async {
      await seedTwoTransactions();
      await pumpScreen(tester, pickCsvContent: () async => csvThree);

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_cancelPreviewButton));
      await tester.pumpAndSettle();

      expect(find.byKey(KozuchiAppKeys.csvImport_previewCard), findsNothing);
      expect(find.byKey(KozuchiAppKeys.csvImport_resultCard), findsNothing);
      expect(await savedCount(), 2);
    });

    testWidgets('プレビューは常にキャンセル導線を持つ', (tester) async {
      await seedTwoTransactions();
      await pumpScreen(tester, pickCsvContent: () async => csvTwo);

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(KozuchiAppKeys.csvImport_cancelPreviewButton),
        findsOneWidget,
      );
      expect(find.text('取り込み前の確認'), findsOneWidget);
      // 照合できているので上書きボタンは出ない
      expect(
        find.byKey(KozuchiAppKeys.csvImport_unverifiedOverrideButton),
        findsNothing,
      );
    });
  });
}

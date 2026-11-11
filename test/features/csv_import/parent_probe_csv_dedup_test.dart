import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/csv_import/domain/csv_import_service.dart';
import 'package:kozuchi/features/csv_import/presentation/screens/csv_import_screen.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';

/// 親探針: 受入基準（#236）を独立に撃つ回帰試練。
///
/// 眷属の試練は個別経路しか撃たないため、ここでは
/// 「CSV → サービス → リポジトリ」の合成と、画面からの実導線を撃つ。
class _UnreadableRepository extends LocalTransactionRepository {
  _UnreadableRepository();

  /// addTransactions に渡されたリスト（書き込み回数の実測用）
  final List<List<TransactionModel>> writes = <List<TransactionModel>>[];

  @override
  Future<TransactionLoadOutcome> loadAllForVerification() async =>
      const TransactionLoadOutcome(
        transactions: <TransactionModel>[],
        verified: false,
      );

  @override
  Future<List<TransactionModel>> loadAll() async =>
      const <TransactionModel>[];

  @override
  Future<List<TransactionModel>> addTransactions(
    List<TransactionModel> transactions,
  ) async {
    writes.add(List<TransactionModel>.of(transactions));
    return List<TransactionModel>.of(transactions);
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

  group('親探針: CSV再取込の重複検出', () {
    test('探針1: 同一CSVを2回取り込んでも合計件数が増えない', () async {
      const service = CsvImportService();
      final repo = const LocalTransactionRepository();

      final first = await service.importCsv(csvTwo);
      expect(first.importedCount, 2);
      expect(first.duplicateCount, 0);

      final second = await service.importCsv(csvTwo);
      expect(second.importedCount, 0);
      expect(second.duplicateCount, 2);
      expect(second.canVerify, isTrue);

      final saved = await repo.loadAll();
      expect(saved, hasLength(2), reason: '2回目で二重計上してはならない');
    });

    test('探針2: 一部重複（3件中2件が既存）なら1件だけ増える', () async {
      const service = CsvImportService();
      final repo = const LocalTransactionRepository();
      await repo.saveAll(const <TransactionModel>[
        TransactionModel(
          amount: 300000,
          purpose: '給与',
          category: '収入',
          datetime: '2026-06-01T12:00:00',
        ),
        TransactionModel(
          amount: -1200,
          purpose: '食費',
          category: 'その他',
          datetime: '2026-06-02T12:00:00',
        ),
      ]);

      const csvThree = 'date,desc,amount\n'
          '2026-06-01,給与,+300000\n'
          '2026-06-02,食費,-1200\n'
          '2026-06-03,書籍,-2400\n';
      final result = await service.importCsv(csvThree);

      expect(result.importedCount, 1);
      expect(result.duplicateCount, 2);

      final saved = await repo.loadAll();
      expect(saved, hasLength(3));
      expect(saved.where((t) => t.purpose == '書籍'), hasLength(1));
    });

    test('探針3: 同日同額でも摘要が違えば両方取り込む（過剰排除しない）', () async {
      const service = CsvImportService();
      final repo = const LocalTransactionRepository();
      await repo.saveAll(const <TransactionModel>[
        TransactionModel(
          amount: -500,
          purpose: '喫茶A',
          category: 'その他',
          datetime: '2026-06-05T12:00:00',
        ),
      ]);

      const csv = 'date,desc,amount\n'
          '2026-06-05,喫茶A,-500\n'
          '2026-06-05,喫茶B,-500\n';
      final result = await service.importCsv(csv);

      expect(result.importedCount, 1, reason: '摘要違いの1件だけが新規');
      expect(result.duplicateCount, 1);

      final saved = await repo.loadAll();
      expect(saved, hasLength(2));
      expect(
        saved.map((t) => t.purpose).toSet(),
        <String>{'喫茶A', '喫茶B'},
      );
    });

    test('探針4: 既存取引を読めない時は黙って全件追記しない（canVerify=false）',
        () async {
      final fake = _UnreadableRepository();
      final service = CsvImportService(repository: fake);

      final result = await service.importCsv(csvTwo);

      expect(result.canVerify, isFalse);
      expect(result.importedCount, 0);
      expect(fake.writes, isEmpty, reason: '読取失敗時に無条件追記してはならない');

      // 明示許可を出した時だけ書き込む
      final preview = await service.previewCsv(csvTwo);
      expect(preview.plan.canVerify, isFalse);
      expect(fake.writes, isEmpty, reason: 'プレビューは書き込まない');

      final committed = await service.commitPreview(
        preview,
        allowUnverified: true,
      );
      expect(committed.importedCount, 2);
      expect(committed.canVerify, isFalse);
      expect(fake.writes, hasLength(1));
    });

    testWidgets('探針5: 画面は読取失敗時に警告を出し、明示操作まで書き込まない', (tester) async {
      final fake = _UnreadableRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: CsvImportScreen(
            service: CsvImportService(repository: fake),
            pickCsvContent: () async => csvTwo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_pickButton));
      await tester.pumpAndSettle();

      expect(find.byKey(KozuchiAppKeys.csvImport_previewCard), findsOneWidget);
      expect(find.text('重複確認ができませんでした'), findsOneWidget);
      expect(fake.writes, isEmpty, reason: '確認カード表示だけでは書き込まない');

      // 主ボタン（重複スキップ）では書き込まれない
      await tester.tap(find.byKey(KozuchiAppKeys.csvImport_confirmButton));
      await tester.pumpAndSettle();
      expect(fake.writes, isEmpty);

      // 明示的な上書き導線でのみ書き込まれる
      await tester.ensureVisible(
        find.byKey(KozuchiAppKeys.csvImport_unverifiedOverrideButton),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(KozuchiAppKeys.csvImport_unverifiedOverrideButton),
      );
      await tester.pumpAndSettle();
      expect(fake.writes, hasLength(1));
      expect(fake.writes.single, hasLength(2));
    });
  });
}

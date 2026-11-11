import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/csv_import/domain/csv_import_service.dart';

/// 既存取引を読めない（照合不能な）リポジトリ
class _UnverifiableRepository extends LocalTransactionRepository {
  _UnverifiableRepository();

  final List<TransactionModel> written = <TransactionModel>[];

  @override
  Future<TransactionLoadOutcome> loadAllForVerification() async {
    return const TransactionLoadOutcome(
      transactions: <TransactionModel>[],
      verified: false,
    );
  }

  @override
  Future<List<TransactionModel>> addTransactions(
    List<TransactionModel> transactions,
  ) async {
    written.addAll(transactions);
    return written;
  }
}

/// 保存に必ず失敗するリポジトリ
class _FailingSaveRepository extends LocalTransactionRepository {
  const _FailingSaveRepository();

  @override
  Future<List<TransactionModel>> addTransactions(
    List<TransactionModel> transactions,
  ) async {
    throw StateError('保存領域が満杯');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const validCsv = 'date,desc,amount\n'
      '2026-06-01,給与,+300000\n'
      '2026-06-02,食費,-1200\n';

  group('CsvImportService 重複スキップ', () {
    test('同一CSVを2回取り込むと2回目は全件重複としてスキップされる', () async {
      const service = CsvImportService();

      final first = await service.importCsv(validCsv);
      expect(first.importedCount, 2);
      expect(first.duplicateCount, 0);
      expect(first.canVerify, isTrue);

      final second = await service.importCsv(validCsv);
      expect(second.importedCount, 0);
      expect(second.duplicateCount, 2);
      expect(second.transactions, isEmpty);

      final saved = await const LocalTransactionRepository().loadAll();
      expect(saved, hasLength(2));
    });

    test('3件中2件が既存なら新規1件のみ取り込む', () async {
      const service = CsvImportService();
      await service.importCsv('date,desc,amount\n'
          '2026-06-01,給与,+300000\n'
          '2026-06-02,食費,-1200\n');

      final result = await service.importCsv('date,desc,amount\n'
          '2026-06-01,給与,+300000\n'
          '2026-06-02,食費,-1200\n'
          '2026-06-03,交通費,-800\n');

      expect(result.importedCount, 1);
      expect(result.duplicateCount, 2);
      expect(result.transactions, hasLength(1));
      expect(result.transactions.single.purpose, '交通費');

      final saved = await const LocalTransactionRepository().loadAll();
      expect(saved, hasLength(3));
    });

    test('同日同額でも摘要が違えば両方とも新規として扱う', () async {
      const service = CsvImportService();

      final result = await service.importCsv('date,desc,amount\n'
          '2026-06-01,コーヒー,-500\n'
          '2026-06-01,ランチ,-500\n');

      expect(result.importedCount, 2);
      expect(result.duplicateCount, 0);
      expect(await const LocalTransactionRepository().loadAll(), hasLength(2));
    });

    test('同一バッチ内の重複行は2件目以降が重複になる', () async {
      const service = CsvImportService();

      final result = await service.importCsv('date,desc,amount\n'
          '2026-06-01,重複行,-500\n'
          '2026-06-01,重複行,-500\n');

      expect(result.importedCount, 1);
      expect(result.duplicateCount, 1);
      expect(await const LocalTransactionRepository().loadAll(), hasLength(1));
    });

    test('includeDuplicates: true なら重複も書き込まれ合計が増える', () async {
      const service = CsvImportService();
      await service.importCsv(validCsv);

      final preview = await service.previewCsv(validCsv);
      expect(preview.plan.duplicateCount, 2);

      final result = await service.commitPreview(
        preview,
        includeDuplicates: true,
      );

      expect(result.importedCount, 2);
      expect(result.duplicateCount, 2);
      expect(result.canVerify, isTrue);
      expect(await const LocalTransactionRepository().loadAll(), hasLength(4));
    });

    test('照合不能なら commit しても書き込みゼロ', () async {
      final fake = _UnverifiableRepository();
      final service = CsvImportService(repository: fake);

      final preview = await service.previewCsv(validCsv);
      expect(preview.plan.canVerify, isFalse);
      expect(preview.plan.total, 2);

      final result = await service.commitPreview(preview);

      expect(result.importedCount, 0);
      expect(result.duplicateCount, 0);
      expect(result.canVerify, isFalse);
      expect(result.transactions, isEmpty);
      expect(fake.written, isEmpty);
    });

    test('照合不能でも allowUnverified: true なら全件書き込む', () async {
      final fake = _UnverifiableRepository();
      final service = CsvImportService(repository: fake);

      final preview = await service.previewCsv(validCsv);
      final result = await service.commitPreview(
        preview,
        allowUnverified: true,
      );

      expect(result.importedCount, 2);
      expect(result.canVerify, isFalse);
      expect(result.unverifiedCount, 2);
      expect(fake.written, hasLength(2));
    });

    test('previewCsv は一切書き込まない', () async {
      const service = CsvImportService();

      final preview = await service.previewCsv(validCsv);

      expect(preview.plan.total, 2);
      expect(preview.plan.freshCount, 2);
      expect(preview.plan.duplicateCount, 0);
      expect(preview.skippedCount, 0);
      expect(await const LocalTransactionRepository().loadAll(), isEmpty);
    });

    test('空CSVは全0で例外を投げない', () async {
      const service = CsvImportService();

      final preview = await service.previewCsv('');
      expect(preview.plan.total, 0);
      expect(preview.plan.canVerify, isTrue);

      final result = await service.commitPreview(preview);
      expect(result.importedCount, 0);
      expect(result.duplicateCount, 0);
      expect(result.skippedCount, 0);
      expect(result.canVerify, isTrue);
      expect(await const LocalTransactionRepository().loadAll(), isEmpty);
    });

    test('不正行があると skippedCount と duplicateCount が併存する', () async {
      const service = CsvImportService();
      await service.importCsv('date,desc,amount\n2026-06-01,給与,+300000\n');

      final result = await service.importCsv('date,desc,amount\n'
          '2026-06-01,給与,+300000\n'
          '完全に不正な行\n'
          '2026-06-05,書籍,-1500\n');

      expect(result.importedCount, 1);
      expect(result.skippedCount, 1);
      expect(result.duplicateCount, 1);
      expect(result.errorMessages, hasLength(1));
    });

    test('保存に失敗しても例外を投げず errorMessages で報告する', () async {
      const service = CsvImportService(
        repository: _FailingSaveRepository(),
      );

      final preview = await service.previewCsv(validCsv);
      final result = await service.commitPreview(preview);

      expect(result.importedCount, 0);
      expect(result.transactions, isEmpty);
      expect(result.errorMessages, hasLength(1));
      expect(result.errorMessages.single, contains('保存に失敗'));
      expect(result.skippedCount, 1);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 追記に必ず失敗する取引リポジトリ（保存失敗の再現）
class _FailingTransactionRepository extends LocalTransactionRepository {
  const _FailingTransactionRepository();

  @override
  Future<List<TransactionModel>> addTransactions(
    List<TransactionModel> transactions,
  ) async {
    throw StateError('disk full');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defRepo = const RecurringTransactionRepository();

  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 6, 15, 9, 0, 0);
  });

  RecurringTransaction monthly() {
    return RecurringTransaction(
      id: 'rent',
      purpose: '家賃',
      category: '住居費',
      amount: -85000,
      frequency: RecurringFrequency.monthly,
      dayOfMonth: 5,
      startDate: DateTime(2026, 1, 5),
    );
  }

  group('RecurringAutoRecorder - 追記失敗時の進捗前進', () {
    test('追記が失敗したら lastGenerated は前進しない（例外は伝播する）', () async {
      await defRepo.addDefinition(monthly());

      final failing = RecurringAutoRecorder(
        transactionRepository: const _FailingTransactionRepository(),
        clock: () => now,
      );

      await expectLater(failing.run(), throwsA(isA<StateError>()));

      // 進捗は据え置き＝次回また同じ期間を生成できる（静かな欠落を防ぐ）
      expect(await defRepo.loadLastGenerated('rent'), isNull);
    });

    test('失敗後の再実行で同じ期間の取引が生成される（欠落しない）', () async {
      await defRepo.addDefinition(monthly());

      final failing = RecurringAutoRecorder(
        transactionRepository: const _FailingTransactionRepository(),
        clock: () => now,
      );
      await expectLater(failing.run(), throwsA(isA<StateError>()));

      final healthy = RecurringAutoRecorder(clock: () => now);
      final result = await healthy.run();

      // 1/5〜6/5 の6件
      expect(result.generatedCount, 6);
      final saved = await const LocalTransactionRepository().loadAll();
      expect(saved, hasLength(6));
      expect(saved.first.datetime, startsWith('2026-01-05'));
      expect(saved.last.datetime, startsWith('2026-06-05'));
    });

    test('成功後は lastGenerated が前進し重複生成されない（回帰）', () async {
      await defRepo.addDefinition(monthly());

      final first = await RecurringAutoRecorder(clock: () => now).run();
      expect(first.generatedCount, 6);
      expect(await defRepo.loadLastGenerated('rent'), isNotNull);

      now = DateTime(2026, 7, 15, 9, 0, 0);
      final second = await RecurringAutoRecorder(clock: () => now).run();

      expect(second.generatedCount, 1);
      expect(second.transactions.single.datetime, startsWith('2026-07-05'));
      final saved = await const LocalTransactionRepository().loadAll();
      expect(saved, hasLength(7));
    });

    test('生成0件でも進捗は前進する（挙動不変）', () async {
      // 6/5 より後に発生しない定義（6/6 開始）
      await defRepo.addDefinition(
        RecurringTransaction(
          id: 'future',
          purpose: '来月から',
          category: 'その他',
          amount: -1000,
          frequency: RecurringFrequency.monthly,
          dayOfMonth: 6,
          startDate: DateTime(2026, 7, 6),
        ),
      );

      final result = await RecurringAutoRecorder(clock: () => now).run();

      expect(result.generatedCount, 0);
      expect(await defRepo.loadLastGenerated('future'), isNotNull);
    });
  });
}

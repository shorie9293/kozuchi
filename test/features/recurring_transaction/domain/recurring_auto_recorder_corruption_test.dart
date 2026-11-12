import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_record_notice.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 追記された取引を数えるだけの取引リポジトリ
class _RecordingTransactionRepository extends LocalTransactionRepository {
  _RecordingTransactionRepository();

  final List<TransactionModel> added = [];

  @override
  Future<List<TransactionModel>> addTransactions(
    List<TransactionModel> transactions,
  ) async {
    added.addAll(transactions);
    return transactions;
  }
}

/// 破損した保存データで自動記帳が「静かに機能停止」しないことの試練。
///
/// 旧実装は破損を空リストとして信じ、0件計上を「定期取引が無い」と
/// 同じ顔で返していた＝利用者には故障が見えない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const defsKey = 'kozuchi_recurring_defs';
  const lastGenKey = 'kozuchi_recurring_last_generated';

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

  group('RecurringAutoRecorder - 破損時の扱い', () {
    test('定義が破損していたら計上せず、破損を結果に明示する', () async {
      SharedPreferences.setMockInitialValues({defsKey: '{"broken":'});
      final txRepo = _RecordingTransactionRepository();

      final recorder = RecurringAutoRecorder(
        transactionRepository: txRepo,
        clock: () => now,
      );
      final result = await recorder.run();

      expect(result.generatedCount, 0);
      expect(result.transactions, isEmpty);
      expect(result.storageUnverified, isTrue);
      expect(result.errorMessage, isNotNull);
      // 不信なデータを根拠に取引を生まない
      expect(txRepo.added, isEmpty);
    });

    test('最終生成日時が破損していたら計上せず、破損を明示する', () async {
      final txRepo = _RecordingTransactionRepository();
      final repo = const RecurringTransactionRepository();
      await repo.saveDefinitions([monthly()]);
      // 定義保存で prefs が上書きされないよう、破損値を再注入する
      final p = await SharedPreferences.getInstance();
      await p.setString(lastGenKey, 'oops');

      final recorder = RecurringAutoRecorder(
        transactionRepository: txRepo,
        clock: () => now,
      );
      final result = await recorder.run();

      expect(result.generatedCount, 0);
      expect(result.storageUnverified, isTrue);
      expect(txRepo.added, isEmpty);
    });

    test('正常時は storageUnverified=false で従来通り計上する', () async {
      await defRepo.addDefinition(monthly());
      final txRepo = _RecordingTransactionRepository();

      final recorder = RecurringAutoRecorder(
        transactionRepository: txRepo,
        clock: () => now,
      );
      final result = await recorder.run();

      expect(result.storageUnverified, isFalse);
      expect(result.errorMessage, isNull);
      expect(result.generatedCount, greaterThan(0));
      expect(txRepo.added, hasLength(result.generatedCount));
    });

    test('破損時に 0件でも lastGenerated を前進させない', () async {
      SharedPreferences.setMockInitialValues({defsKey: '{"broken":'});
      final txRepo = _RecordingTransactionRepository();

      final recorder = RecurringAutoRecorder(
        transactionRepository: txRepo,
        clock: () => now,
      );
      await recorder.run();

      final p = await SharedPreferences.getInstance();
      expect(p.getString(lastGenKey), isNull);
    });
  });

  group('RecurringAutoRecordNotice - 破損の可視化', () {
    test('破損時は沈黙せず警告を出す（0件を正常と混同しない）', () {
      const result = RecurringAutoRecordResult(
        generatedCount: 0,
        transactions: [],
        storageUnverified: true,
        errorMessage: '定期取引の保存データが壊れています',
      );

      final notice = RecurringAutoRecordNotice.fromResult(result);

      expect(notice.shouldShow, isTrue);
      expect(notice.isFailure, isTrue);
      expect(notice.message, isNotNull);
      expect(notice.message, contains('壊れ'));
    });

    test('破損していない0件は従来通り沈黙する（回帰）', () {
      const result = RecurringAutoRecordResult(
        generatedCount: 0,
        transactions: [],
      );

      final notice = RecurringAutoRecordNotice.fromResult(result);

      expect(notice.shouldShow, isFalse);
      expect(notice.isFailure, isFalse);
    });

    test('破損かつ計上ありでも警告を優先する', () {
      const result = RecurringAutoRecordResult(
        generatedCount: 2,
        transactions: [],
        storageUnverified: true,
      );

      final notice = RecurringAutoRecordNotice.fromResult(result);

      expect(notice.isFailure, isTrue);
      expect(notice.shouldShow, isTrue);
    });
  });
}

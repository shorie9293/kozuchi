import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_record_notice.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 親探針: 子の試練が個別に撃たない「合成」と「復旧の実効性」を独立に撃つ。
///
/// 破損を検知して止めるだけでは足りない。**退避 → 再登録 → 自動記帳が回る**
/// までが一本の導線として通らなければ、利用者は壊れたまま立ち往生する。
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const defsKey = 'kozuchi_recurring_defs';
  const lastGenKey = 'kozuchi_recurring_last_generated';

  const repo = RecurringTransactionRepository();

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('親探針 - 破損からの復旧が一本の導線として通る', () {
    test('探針1: 破損→退避→再登録→自動記帳が再び回る（合成）', () async {
      SharedPreferences.setMockInitialValues({defsKey: '{"broken":'});
      final txRepo = _RecordingTransactionRepository();
      final recorder = RecurringAutoRecorder(
        transactionRepository: txRepo,
        clock: () => DateTime(2026, 6, 15, 9),
      );

      // 1. 破損中は計上しない（不信なデータで副作用を起こさない）
      final before = await recorder.run();
      expect(before.storageUnverified, isTrue);
      expect(txRepo.added, isEmpty);

      // 2. 退避して空ける
      expect(await repo.archiveCorruptData(), isTrue);

      // 3. 再登録でき、以後 verified=true
      expect((await repo.addDefinition(monthly())).ok, isTrue);
      expect((await repo.loadDefinitionsResult()).verified, isTrue);

      // 4. 自動記帳が回り、実際に取引が生まれる
      final after = await recorder.run();
      expect(after.storageUnverified, isFalse);
      expect(after.generatedCount, greaterThan(0));
      expect(txRepo.added, hasLength(after.generatedCount));
    });

    test('探針2: 進捗データ破損でも退避後に自動記帳が再開し進捗を残す', () async {
      await repo.saveDefinitions([monthly()]);
      final p = await SharedPreferences.getInstance();
      await p.setString(lastGenKey, 'oops');

      final txRepo = _RecordingTransactionRepository();
      final recorder = RecurringAutoRecorder(
        transactionRepository: txRepo,
        clock: () => DateTime(2026, 6, 15, 9),
      );

      final blocked = await recorder.run();
      expect(blocked.storageUnverified, isTrue);
      expect(txRepo.added, isEmpty);

      expect(await repo.archiveCorruptData(), isTrue);
      final resumed = await recorder.run();
      expect(resumed.generatedCount, greaterThan(0));
      expect(await repo.loadLastGenerated('rent'), isNotNull);
    });

    test('探針3: 一部破損のまま削除を試みても、読めた定義を消さない', () async {
      const raw = '[{"id":"rent","purpose":"家賃","category":"住居費",'
          '"amount":-85000,"frequency":"monthly","dayOfMonth":5,'
          '"startDate":"2026-01-05T00:00:00.000"}, "壊れた要素"]';
      SharedPreferences.setMockInitialValues({defsKey: raw});

      final result = await repo.removeDefinition('rent');

      expect(result.ok, isFalse);
      final p = await SharedPreferences.getInstance();
      expect(p.getString(defsKey), raw);
      // 読めた1件は依然として一覧に出る（利用者が状況を把握できる）
      expect((await repo.loadDefinitions()).single.id, 'rent');
    });

    test('探針4: 退避は冪等で、退避データは原本と完全一致する', () async {
      const raw = '{"broken": [1,2,3]';
      SharedPreferences.setMockInitialValues({defsKey: raw});

      expect(await repo.archiveCorruptData(), isTrue);
      // 2回目は退避対象が無い
      expect(await repo.archiveCorruptData(), isFalse);

      final p = await SharedPreferences.getInstance();
      final backups = p
          .getKeys()
          .where((k) => k.startsWith(RecurringTransactionRepository.backupKeyPrefix))
          .toList();
      expect(backups, hasLength(1));
      expect(p.getString(backups.single), raw);
    });

    test('探針5: 健全なデータでは退避が誤発動せず、往復後も verified=true', () async {
      await repo.saveDefinitions([monthly()]);
      await repo.saveLastGenerated('rent', DateTime(2026, 5, 5));

      expect(await repo.archiveCorruptData(), isFalse);
      final loaded = await repo.loadDefinitionsResult();
      expect(loaded.verified, isTrue);
      expect(loaded.definitions, hasLength(1));
      expect(await repo.loadLastGenerated('rent'), DateTime(2026, 5, 5));
    });

    test('探針6: 破損時に利用者が目にする通知は「壊れている」と告げる', () async {
      SharedPreferences.setMockInitialValues({defsKey: '{"broken":'});
      final recorder = RecurringAutoRecorder(
        transactionRepository: _RecordingTransactionRepository(),
        clock: () => DateTime(2026, 6, 15, 9),
      );

      final notice = RecurringAutoRecordNotice.fromResult(await recorder.run());

      expect(notice.shouldShow, isTrue);
      expect(notice.message, contains('壊れ'));
      // 「定期取引を0件記帳しました」のような正常顔の文言を出さない
      expect(notice.message, isNot(contains('0件記帳')));
    });

    test('探針7: 進捗破損でも loadLastGenerated は例外を投げず null（既存経路を壊さない）', () async {
      SharedPreferences.setMockInitialValues({lastGenKey: '壊れた'});

      final value = await repo.loadLastGenerated('rent');
      expect(value, isNull);
    });
  });
}

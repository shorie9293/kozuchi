import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/csv_import/domain/csv_import_service.dart';
import 'package:kozuchi/features/recurring_transaction/data/recurring_transaction_repository.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_record_notice.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 取引ストレージ破損時に対称性を撃つ試練。
///
/// CSV経路と定期取引経路は、同じ破損に対して**同じ結論**を出さねばならない。
/// すなわち「書き込み0・既存原本不変・利用者に告げる」の三拍子。
/// 片方だけが黙って通ると、利用者には壊れた事実が届かないまま履歴が消える。
const String _txKey = 'kozuchi_local_transactions';
const String _lastGenKey = 'kozuchi_recurring_last_generated';

const TransactionModel _book = TransactionModel(
  amount: -800,
  purpose: '書籍',
  category: '教養',
  datetime: '2026-06-03T12:00:00',
);

/// 正常1件の JSON に壊れた要素を継ぎ足した「破損」生文字列
String _corruptRaw() {
  const healthy =
      '[{"amount":-500,"purpose":"ランチ","category":"食費",'
      '"datetime":"2026-06-01T12:00:00","receiptImagePath":null,"id":null}]';
  return '${healthy.substring(0, healthy.length - 1)},{"壊れた"}]';
}

/// 追記呼出の回数を数えつつ、実リポジトリの挙動（破損時 throw）を保つ
class _CountingTransactionRepository extends LocalTransactionRepository {
  _CountingTransactionRepository();

  int calls = 0;

  @override
  Future<List<TransactionModel>> addTransactions(
    List<TransactionModel> transactions,
  ) {
    calls++;
    return super.addTransactions(transactions);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const defRepo = RecurringTransactionRepository();
  const txRepo = LocalTransactionRepository();
  final now = DateTime(2026, 6, 15, 9);

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

  /// 定期取引定義は健全、取引ストレージのみ破損という状況を作る
  Future<String> setUpCorruptTransactionStorage() async {
    SharedPreferences.setMockInitialValues({});
    await defRepo.addDefinition(monthly());
    final prefs = await SharedPreferences.getInstance();
    final raw = _corruptRaw();
    await prefs.setString(_txKey, raw);
    return raw;
  }

  group('取引ストレージ破損 - 定期取引経路', () {
    test('run() は例外を投げず、0件・storageUnverified を返し追記しない', () async {
      await setUpCorruptTransactionStorage();
      final counting = _CountingTransactionRepository();
      final recorder = RecurringAutoRecorder(
        transactionRepository: counting,
        clock: () => now,
      );

      // 例外が外へ漏れると画面は「自動記帳に失敗しました」しか言えなくなる
      final result = await recorder.run();

      expect(result.generatedCount, 0);
      expect(result.transactions, isEmpty);
      expect(result.storageUnverified, isTrue);
      expect(result.errorMessage, contains('壊れ'));
      expect(counting.calls, 0, reason: '破損を検知したら追記を試みない');
    });

    test('lastGenerated は前進しない（次回起動で同じ期間を再生成できる）', () async {
      await setUpCorruptTransactionStorage();
      final recorder = RecurringAutoRecorder(
        transactionRepository: _CountingTransactionRepository(),
        clock: () => now,
      );

      await recorder.run();

      expect(await defRepo.loadLastGenerated('rent'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_lastGenKey), isNull);
    });

    test('通知は沈黙せず「壊れ」を告げ、正常顔の0件文言を出さない', () async {
      await setUpCorruptTransactionStorage();
      final recorder = RecurringAutoRecorder(
        transactionRepository: _CountingTransactionRepository(),
        clock: () => now,
      );

      final notice = RecurringAutoRecordNotice.fromResult(await recorder.run());

      expect(notice.shouldShow, isTrue);
      expect(notice.isFailure, isTrue);
      expect(notice.message, contains('壊れ'));
      expect(notice.message, isNot(contains('0件記帳')));
    });
  });

  group('取引ストレージ破損 - CSV経路との対称性', () {
    test('同一破損データで両経路とも「書き込み0・原本不変」になる', () async {
      final raw = await setUpCorruptTransactionStorage();
      const csv = 'date,desc,amount\n'
          '2026-06-10,書籍,-800\n'
          '2026-06-11,文具,-300\n';
      const service = CsvImportService();
      final recorder = RecurringAutoRecorder(
        transactionRepository: _CountingTransactionRepository(),
        clock: () => now,
      );
      final prefs = await SharedPreferences.getInstance();

      // CSV経路: 照合不能なので既定では書かない。明示許可時も破損なら書かない
      final preview = await service.previewCsv(csv);
      expect(preview.plan.canVerify, isFalse);
      final csvResult =
          await service.commitPreview(preview, allowUnverified: true);

      expect(csvResult.importedCount, 0);
      expect(csvResult.transactions, isEmpty);
      expect(csvResult.canVerify, isFalse);
      expect(csvResult.duplicateCount, 0);
      expect(csvResult.unverifiedCount, preview.plan.incoming.length);
      expect(csvResult.skippedCount, preview.errorMessages.length + 1);
      expect(csvResult.errorMessages.last, contains('見送り'));
      expect(csvResult.errorMessages.last, contains('変更していません'));
      expect(prefs.getString(_txKey), raw, reason: 'CSV経路が原本を書き換えた');

      // 定期取引経路: 同じ結論に落ちる
      final recResult = await recorder.run();
      expect(recResult.generatedCount, 0);
      expect(recResult.storageUnverified, isTrue);
      expect(prefs.getString(_txKey), raw, reason: '自動記帳経路が原本を書き換えた');
    });
  });

  group('健全なデータでは従来通り書く（退行なし）', () {
    test('CSVも自動記帳も通常どおり追記する', () async {
      SharedPreferences.setMockInitialValues({});
      await defRepo.addDefinition(monthly());
      const service = CsvImportService();
      final recorder = RecurringAutoRecorder(clock: () => now);

      final csvResult = await service.importCsv(
        'date,desc,amount\n2026-06-01,給与,+300000\n',
      );
      expect(csvResult.importedCount, 1);
      expect(csvResult.canVerify, isTrue);

      final recResult = await recorder.run();
      expect(recResult.storageUnverified, isFalse);
      expect(recResult.generatedCount, 6);

      final stored = await txRepo.loadAll();
      expect(stored, hasLength(1 + recResult.generatedCount));
      expect(
        stored.where((t) => t.purpose == '家賃'),
        hasLength(recResult.generatedCount),
      );
    });
  });

  group('破損からの復旧', () {
    test('退避は原本を消さないが、原本を空けた後は追記が通る（再開できる）', () async {
      final raw = await setUpCorruptTransactionStorage();
      final prefs = await SharedPreferences.getInstance();

      // 退避: 原本の複製を残すだけ（原本は壊れたまま＝上書きはしない）
      expect(await txRepo.archiveCorruptData(), isTrue);
      expect(prefs.getString(_txKey), raw);
      final backups = prefs
          .getKeys()
          .where((k) => k.startsWith(LocalTransactionRepository.backupKeyPrefix))
          .toList();
      expect(backups, hasLength(1));
      expect(prefs.getString(backups.single), raw, reason: '退避データが原本と不一致');

      // 原本が壊れたままなら、依然として書かない（履歴消失を避ける）
      await expectLater(
        txRepo.addTransactions(const <TransactionModel>[_book]),
        throwsA(isA<TransactionStorageCorruptException>()),
      );

      // 利用者が破損原本を空けて初めて再開できる
      await txRepo.clear();
      final updated = await txRepo.addTransactions(
        const <TransactionModel>[_book],
      );
      expect(updated, hasLength(1));
      expect(updated.single.purpose, '書籍');
    });

    test('退避＋原本を空けると自動記帳も再開し、進捗を残す', () async {
      await setUpCorruptTransactionStorage();
      final recorder = RecurringAutoRecorder(clock: () => now);

      expect(await txRepo.archiveCorruptData(), isTrue);
      await txRepo.clear();

      final resumed = await recorder.run();

      expect(resumed.storageUnverified, isFalse);
      expect(resumed.generatedCount, 6);
      expect(await defRepo.loadLastGenerated('rent'), isNotNull);
      expect(await txRepo.loadAll(), hasLength(6));
    });
  });
}

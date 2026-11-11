import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/domain/transaction_import_deduplicator.dart';

void main() {
  const deduplicator = TransactionImportDeduplicator();

  TransactionModel makeTx({
    int amount = -500,
    String purpose = 'ランチ',
    String category = '食費',
    String datetime = '2026-06-01T12:00:00',
  }) {
    return TransactionModel(
      amount: amount,
      purpose: purpose,
      category: category,
      datetime: datetime,
    );
  }

  group('TransactionImportDeduplicator.plan', () {
    test('空の incoming は全件数0で canVerify は維持される', () {
      final plan = deduplicator.plan(
        incoming: const <TransactionModel>[],
        existing: [makeTx()],
      );

      expect(plan.total, 0);
      expect(plan.freshCount, 0);
      expect(plan.duplicateCount, 0);
      expect(plan.canVerify, isTrue);
      expect(plan.hasDuplicates, isFalse);
    });

    test('既存が空なら全件が fresh になる', () {
      final incoming = [makeTx(), makeTx(amount: -800, purpose: '夕食')];

      final plan = deduplicator.plan(
        incoming: incoming,
        existing: const <TransactionModel>[],
      );

      expect(plan.freshCount, 2);
      expect(plan.duplicateCount, 0);
      expect(plan.total, 2);
      expect(plan.canVerify, isTrue);
    });

    test('完全同一の取引を2回取り込むと全件 duplicates になる', () {
      final existing = [makeTx(), makeTx(amount: -1200, purpose: '書籍')];
      final incoming = [makeTx(), makeTx(amount: -1200, purpose: '書籍')];

      final plan = deduplicator.plan(incoming: incoming, existing: existing);

      expect(plan.freshCount, 0);
      expect(plan.duplicateCount, 2);
      expect(plan.hasDuplicates, isTrue);
    });

    test('3件中2件が既存なら fresh1・duplicates2 になる', () {
      final existing = [makeTx(), makeTx(amount: -1200, purpose: '書籍')];
      final incoming = [
        makeTx(),
        makeTx(amount: -1200, purpose: '書籍'),
        makeTx(amount: -300, purpose: 'カフェ'),
      ];

      final plan = deduplicator.plan(incoming: incoming, existing: existing);

      expect(plan.freshCount, 1);
      expect(plan.duplicateCount, 2);
      expect(plan.fresh.single.purpose, 'カフェ');
      expect(plan.duplicates.map((t) => t.purpose), ['ランチ', '書籍']);
    });

    test('同日同額でも摘要が違えば両方 fresh（正当な別取引を潰さない）', () {
      final existing = [makeTx(purpose: 'ランチ')];
      final incoming = [makeTx(purpose: 'ランチ'), makeTx(purpose: '夕食')];

      final plan = deduplicator.plan(incoming: incoming, existing: existing);

      expect(plan.freshCount, 1);
      expect(plan.duplicateCount, 1);
      expect(plan.fresh.single.purpose, '夕食');
    });

    test('金額の符号が違えば別取引として扱う', () {
      final existing = [makeTx(amount: -500)];
      final incoming = [makeTx(amount: 500)];

      final plan = deduplicator.plan(incoming: incoming, existing: existing);

      expect(plan.freshCount, 1);
      expect(plan.duplicateCount, 0);
    });

    test('日時の表記が ISO 日時でも日付のみでも同一視する', () {
      final existing = [makeTx(datetime: '2026-06-01T12:00:00')];
      final incoming = [makeTx(datetime: '2026-06-01')];

      final plan = deduplicator.plan(incoming: incoming, existing: existing);

      expect(plan.freshCount, 0);
      expect(plan.duplicateCount, 1);
    });

    test('全角の摘要でも正規化されて重複と判定する', () {
      final existing = [makeTx(purpose: 'starbucks')];
      final incoming = [makeTx(purpose: 'ＳＴＡＲＢＵＣＫＳ')];

      final plan = deduplicator.plan(incoming: incoming, existing: existing);

      expect(plan.freshCount, 0);
      expect(plan.duplicateCount, 1);
    });

    test('連続空白の違いは正規化されて重複と判定する', () {
      final existing = [makeTx(purpose: 'スターバックス 新宿店')];
      final incoming = [makeTx(purpose: 'スターバックス   新宿店')];

      final plan = deduplicator.plan(incoming: incoming, existing: existing);

      expect(plan.freshCount, 0);
      expect(plan.duplicateCount, 1);
    });

    test('同一バッチ内の完全重複行は fresh1・duplicates1 になる', () {
      final incoming = [makeTx(), makeTx()];

      final plan = deduplicator.plan(
        incoming: incoming,
        existing: const <TransactionModel>[],
      );

      expect(plan.freshCount, 1);
      expect(plan.duplicateCount, 1);
    });

    test('canVerify が false なら fresh0・duplicates0 で incoming を保持する', () {
      final incoming = [makeTx(), makeTx(amount: -900, purpose: '電気代')];

      final plan = deduplicator.plan(
        incoming: incoming,
        existing: const <TransactionModel>[],
        canVerify: false,
      );

      expect(plan.canVerify, isFalse);
      expect(plan.freshCount, 0);
      expect(plan.duplicateCount, 0);
      expect(plan.total, 2);
      expect(plan.incoming, hasLength(2));
    });

    test('空文字だらけの取引でも例外を投げない', () {
      final empty = makeTx(purpose: '', category: '', datetime: '');
      final incoming = [empty, empty];

      final plan = deduplicator.plan(
        incoming: incoming,
        existing: const <TransactionModel>[],
      );

      expect(plan.canVerify, isTrue);
      expect(plan.freshCount, 1);
      expect(plan.duplicateCount, 1);
    });

    test('短い datetime でも例外を投げず生値で照合する', () {
      final incoming = [makeTx(datetime: '2026'), makeTx(datetime: '2026')];

      final plan = deduplicator.plan(
        incoming: incoming,
        existing: const <TransactionModel>[],
      );

      expect(plan.freshCount, 1);
      expect(plan.duplicateCount, 1);
    });

    test('fresh は入力順を保つ', () {
      final incoming = [
        makeTx(purpose: 'A'),
        makeTx(purpose: 'A'), // 重複
        makeTx(purpose: 'B'),
        makeTx(purpose: 'C'),
      ];

      final plan = deduplicator.plan(
        incoming: incoming,
        existing: const <TransactionModel>[],
      );

      expect(plan.fresh.map((t) => t.purpose), ['A', 'B', 'C']);
    });

    test('incoming リストを破壊しない', () {
      final incoming = [makeTx(purpose: 'B'), makeTx(purpose: 'A')];
      final snapshot = List<TransactionModel>.of(incoming);

      deduplicator.plan(
        incoming: incoming,
        existing: const <TransactionModel>[],
      );

      expect(incoming, snapshot);
      expect(incoming.map((t) => t.purpose), ['B', 'A']);
    });
  });

  group('TransactionImportDeduplicator.keyOf', () {
    test('同一内容の取引は同じキーを返す', () {
      expect(TransactionImportDeduplicator.keyOf(makeTx()), TransactionImportDeduplicator.keyOf(makeTx()));
    });

    test('摘要が違えばキーも違う', () {
      expect(
        TransactionImportDeduplicator.keyOf(makeTx(purpose: 'ランチ')),
        isNot(TransactionImportDeduplicator.keyOf(makeTx(purpose: '夕食'))),
      );
    });

    test('カテゴリが違えばキーも違う', () {
      expect(
        TransactionImportDeduplicator.keyOf(makeTx(category: '食費')),
        isNot(TransactionImportDeduplicator.keyOf(makeTx(category: '日用品'))),
      );
    });

    test('キーは日付部分に datetime の先頭10文字を含む', () {
      final key = TransactionImportDeduplicator.keyOf(makeTx(datetime: '2026-06-01T12:00:00'));

      expect(key, contains('2026-06-01'));
      expect(key, isNot(contains('T12:00:00')));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_record_notice.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';

void main() {
  group('RecurringAutoRecordNotice', () {
    test('生成0件は沈黙する（message は null）', () {
      const result = RecurringAutoRecordResult(
        generatedCount: 0,
        transactions: [],
      );

      final notice = RecurringAutoRecordNotice.fromResult(result);

      expect(notice.shouldShow, isFalse);
      expect(notice.message, isNull);
      expect(notice.isFailure, isFalse);
      expect(notice.generatedCount, 0);
    });

    test('生成3件は件数を含むメッセージを出す', () {
      const result = RecurringAutoRecordResult(
        generatedCount: 3,
        transactions: [],
      );

      final notice = RecurringAutoRecordNotice.fromResult(result);

      expect(notice.shouldShow, isTrue);
      expect(notice.message, isNotNull);
      expect(notice.message, contains('3件'));
      expect(notice.isFailure, isFalse);
      expect(notice.generatedCount, 3);
    });

    test('failure は失敗を可視化する', () {
      final notice = RecurringAutoRecordNotice.failure(StateError('boom'));

      expect(notice.isFailure, isTrue);
      expect(notice.message, isNotNull);
      expect(notice.shouldShow, isTrue);
      expect(notice.message, contains('失敗'));
      expect(notice.generatedCount, 0);
    });

    test('failure は引数なしでも生成できる', () {
      final notice = RecurringAutoRecordNotice.failure();

      expect(notice.isFailure, isTrue);
      expect(notice.shouldShow, isTrue);
    });
  });
}

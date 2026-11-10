import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_history/domain/bulk_delete_service.dart';

/// 一括削除の逐次実行を担う純粋サービスの試練。
///
/// 仕様:
/// - 1 件ずつ順に削除し、個々の失敗は握って failedIds に載せ、残りを継続する
/// - 例外は外へ投げない（絶対）
/// - 成功した取引を元順序のまま deletedItems で返す（Undo 復元用）
TransactionModel tx(String id) => TransactionModel(
      id: id,
      amount: -100,
      purpose: 'purpose-$id',
      category: '食費',
      datetime: '2026-11-01T12:00:00',
    );

void main() {
  group('BulkDeleteService', () {
    test('全成功なら deleted 件数・deletedItems が元順序で揃う', () async {
      final targets = [tx('a'), tx('b'), tx('c')];
      final calls = <String>[];
      final service = BulkDeleteService(
        deleteOne: (t) async {
          calls.add(t.id!);
          return true;
        },
      );

      final outcome = await service.run(targets);

      expect(outcome.deleted, 3);
      expect(outcome.failed, 0);
      expect(outcome.failedIds, isEmpty);
      expect(outcome.deletedItems.map((t) => t.id), ['a', 'b', 'c']);
      expect(calls, ['a', 'b', 'c'], reason: '1件ずつ順に実行する');
    });

    test('途中失敗（2件目だけ false）でも残りを継続し failed=1・deleted=2', () async {
      final targets = [tx('a'), tx('b'), tx('c')];
      var calls = 0;
      final service = BulkDeleteService(
        deleteOne: (t) async {
          calls++;
          return t.id != 'b';
        },
      );

      final outcome = await service.run(targets);

      expect(outcome.deleted, 2);
      expect(outcome.failed, 1);
      expect(outcome.failedIds, ['b']);
      expect(outcome.deletedItems.map((t) => t.id), ['a', 'c']);
      expect(calls, 3, reason: '失敗しても残りを継続する');
    });

    test('deleteOne が例外を投げても外へ漏れず failedIds に載る', () async {
      final targets = [tx('a'), tx('b'), tx('c')];
      final errors = <Object>[];
      final service = BulkDeleteService(
        deleteOne: (t) async {
          if (t.id == 'b') throw StateError('network down');
          return true;
        },
        onError: (message, error) => errors.add(error),
      );

      final outcome = await service.run(targets);

      expect(outcome.deleted, 2);
      expect(outcome.failed, 1);
      expect(outcome.failedIds, ['b']);
      expect(outcome.deletedItems.map((t) => t.id), ['a', 'c']);
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });

    test('onError 未指定でも例外は投げず、失敗として計上する', () async {
      final service = BulkDeleteService(
        deleteOne: (t) async => throw Exception('boom'),
      );

      final outcome = await service.run([tx('a'), tx('b')]);

      expect(outcome.deleted, 0);
      expect(outcome.failed, 2);
      expect(outcome.failedIds, ['a', 'b']);
      expect(outcome.deletedItems, isEmpty);
    });

    test('空の対象なら何も実行しない', () async {
      final calls = <String>[];
      final service = BulkDeleteService(
        deleteOne: (t) async {
          calls.add(t.id!);
          return true;
        },
      );

      final outcome = await service.run(const []);

      expect(outcome.deleted, 0);
      expect(outcome.failed, 0);
      expect(outcome.failedIds, isEmpty);
      expect(outcome.deletedItems, isEmpty);
      expect(calls, isEmpty);
    });
  });
}

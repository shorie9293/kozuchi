import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';

/// 保存キー（本体と同じ `kozuchi_local_transactions`）
const String _key = 'kozuchi_local_transactions';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalTransactionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = const LocalTransactionRepository();
  });

  group('loadAllForVerification', () {
    test('キー不在なら verified true で空リストを返す', () async {
      final outcome = await repository.loadAllForVerification();

      expect(outcome.verified, isTrue);
      expect(outcome.transactions, isEmpty);
    });

    test('正常な保存データは verified true で復元される', () async {
      const tx = TransactionModel(
        amount: -1200,
        purpose: '書籍',
        category: '教養',
        datetime: '2026-06-01T12:00:00',
      );
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([tx.toJson()]),
      });

      final outcome = await repository.loadAllForVerification();

      expect(outcome.verified, isTrue);
      expect(outcome.transactions, hasLength(1));
      expect(outcome.transactions.single.amount, -1200);
      expect(outcome.transactions.single.purpose, '書籍');
      expect(outcome.transactions.single.datetime, '2026-06-01T12:00:00');
    });

    test('空配列の保存データは verified true で空リストを返す', () async {
      SharedPreferences.setMockInitialValues({_key: '[]'});

      final outcome = await repository.loadAllForVerification();

      expect(outcome.verified, isTrue);
      expect(outcome.transactions, isEmpty);
    });

    test('破損JSONは verified false で空リストを返す', () async {
      SharedPreferences.setMockInitialValues({_key: '{壊れた'});

      final outcome = await repository.loadAllForVerification();

      expect(outcome.verified, isFalse);
      expect(outcome.transactions, isEmpty);
    });

    test('配列でないJSONは verified false になる', () async {
      SharedPreferences.setMockInitialValues({_key: '{"a":1}'});

      final outcome = await repository.loadAllForVerification();

      expect(outcome.verified, isFalse);
      expect(outcome.transactions, isEmpty);
    });

    test('要素の型が不正なら verified false になる', () async {
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode(['文字列は取引ではない']),
      });

      final outcome = await repository.loadAllForVerification();

      expect(outcome.verified, isFalse);
      expect(outcome.transactions, isEmpty);
    });

    test('複数件の保存データも順序どおり復元される', () async {
      const txs = [
        TransactionModel(
          amount: -500,
          purpose: 'ランチ',
          category: '食費',
          datetime: '2026-06-01T12:00:00',
        ),
        TransactionModel(
          amount: 3000,
          purpose: '給与',
          category: '収入',
          datetime: '2026-06-02T12:00:00',
        ),
      ];
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode(txs.map((t) => t.toJson()).toList()),
      });

      final outcome = await repository.loadAllForVerification();

      expect(outcome.verified, isTrue);
      expect(outcome.transactions.map((t) => t.purpose), ['ランチ', '給与']);
    });
  });

  group('loadAll', () {
    test('正常時は中身をそのまま返す（挙動不変）', () async {
      const tx = TransactionModel(
        amount: -500,
        purpose: 'ランチ',
        category: '食費',
        datetime: '2026-06-01T12:00:00',
      );
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([tx.toJson()]),
      });

      final loaded = await repository.loadAll();

      expect(loaded, hasLength(1));
      expect(loaded.single.purpose, 'ランチ');
    });

    test('破損時は空リストを返す（従来挙動が不変）', () async {
      SharedPreferences.setMockInitialValues({_key: '{壊れた'});

      final loaded = await repository.loadAll();

      expect(loaded, isEmpty);
    });

    test('キー不在時は空リストを返す', () async {
      final loaded = await repository.loadAll();

      expect(loaded, isEmpty);
    });
  });
}

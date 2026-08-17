import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/csv_import/data/local_transaction_repository.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TransactionModel apiTx(int amount, String purpose) => TransactionModel(
        amount: amount,
        purpose: purpose,
        category: 'その他',
        datetime: '2026-06-10T09:00:00',
      );

  TransactionModel localTx(int amount, String purpose) => TransactionModel(
        amount: amount,
        purpose: purpose,
        category: 'その他',
        datetime: '2026-06-12T10:00:00',
      );

  group('TransactionController ローカル取引統合', () {
    test('localRepository指定時はAPI取引にローカル取引が統合される', () async {
      final localRepo = const LocalTransactionRepository();
      await localRepo.addTransactions([localTx(-450, 'CSVインポート取引')]);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [apiTx(100000, 'ボーナス').toJson()],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final controller = TransactionController(
        service: TransactionService(client: client),
        localRepository: localRepo,
      );

      await controller.fetchTransactions();

      // API 1件 + ローカル 1件 = 2件
      expect(controller.transactions, hasLength(2));
      final purposes =
          controller.transactions.map((t) => t.purpose).toSet();
      expect(purposes, contains('ボーナス'));
      expect(purposes, contains('CSVインポート取引'));
    });

    test('localRepository未指定時は従来通りAPI取引のみ', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [apiTx(100000, 'ボーナス').toJson()],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final controller = TransactionController(
        service: TransactionService(client: client),
      );

      await controller.fetchTransactions();
      expect(controller.transactions, hasLength(1));
      expect(controller.transactions[0].purpose, 'ボーナス');
    });

    test('ローカル取引は日時の降順でAPI取引とソート統合される', () async {
      final localRepo = const LocalTransactionRepository();
      // ローカルは6/12
      await localRepo.addTransactions([localTx(-450, 'CSVインポート取引')]);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            // APIは6/10（ローカルより古い）
            'data': [apiTx(100000, 'ボーナス').toJson()],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final controller = TransactionController(
        service: TransactionService(client: client),
        localRepository: localRepo,
      );

      await controller.fetchTransactions();

      // 日時の新しいローカル(6/12)が先頭に来る
      expect(controller.transactions.first.purpose, 'CSVインポート取引');
      expect(controller.transactions.last.purpose, 'ボーナス');
    });

    test('localRepositoryが空の場合はAPI取引のみ', () async {
      final localRepo = const LocalTransactionRepository();
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [apiTx(100000, 'ボーナス').toJson()],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final controller = TransactionController(
        service: TransactionService(client: client),
        localRepository: localRepo,
      );

      await controller.fetchTransactions();
      expect(controller.transactions, hasLength(1));
    });
  });
}

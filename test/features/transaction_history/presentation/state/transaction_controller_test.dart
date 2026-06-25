import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';

/// UTF-8の成功レスポンスを生成するヘルパー
http.Response _okResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// エラーレスポンスを生成
http.Response _errorResponse(int statusCode, String body) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'text/plain; charset=utf-8'},
  );
}

/// 成功レスポンスを返すMockClientを作成
MockClient _successMockClient() {
  return MockClient((request) async {
    return _okResponse({
      'data': [
        {'amount': 100000, 'purpose': 'ボーナス', 'category': '収入', 'datetime': '2026-06-15T10:00:00'},
        {'amount': -5000, 'purpose': '家賃', 'category': '住居費', 'datetime': '2026-06-01T09:00:00'},
      ],
    });
  });
}

/// エラーレスポンスを返すMockClientを作成
MockClient _errorMockClient() {
  return MockClient((request) async {
    return _errorResponse(500, 'Internal Server Error');
  });
}

void main() {
  group('TransactionController', () {
    // ── 初期化 ──────────────────────────────────

    test('デフォルトフィルタ（全件・日付範囲なし）で初期化される', () {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );

      expect(controller.filter.type, TransactionFilterType.all);
      expect(controller.filter.startDate, isNull);
      expect(controller.filter.endDate, isNull);
      expect(controller.transactions, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
    });

    test('初期フィルタを指定して初期化できる', () {
      final initialFilter = TransactionFilter(
        type: TransactionFilterType.income,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 30),
      );

      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
        initialFilter: initialFilter,
      );

      expect(controller.filter.type, TransactionFilterType.income);
      expect(controller.filter.startDate, DateTime(2026, 6, 1));
      expect(controller.filter.endDate, DateTime(2026, 6, 30));
    });

    // ── データ取得 成功 ─────────────────────────

    test('fetchTransactions 成功時に取引一覧が更新されエラーはnullになる', () async {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );

      // 通知回数を追跡
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.fetchTransactions();

      expect(controller.transactions.length, 2);
      expect(controller.transactions[0].amount, 100000);
      expect(controller.transactions[0].purpose, 'ボーナス');
      expect(controller.transactions[1].amount, -5000);
      expect(controller.transactions[1].purpose, '家賃');
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      // notifyListeners が最低2回呼ばれる（loading開始→data到着）
      expect(notifyCount, greaterThanOrEqualTo(2));
    });

    // ── データ取得 失敗 ─────────────────────────

    test('fetchTransactions 失敗時にエラーが設定され取引一覧は空になる', () async {
      final controller = TransactionController(
        service: TransactionService(client: _errorMockClient()),
      );

      await controller.fetchTransactions();

      expect(controller.transactions, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNotNull);
      expect(controller.error, contains('TransactionServiceException'));
    });

    // ── フィルタ更新 ────────────────────────────

    test('updateFilter で異なるフィルタを渡すとフィルタが更新される', () {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );

      final newFilter = TransactionFilter(
        type: TransactionFilterType.income,
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 30),
      );

      // updateFilter は void（非同期のfetchTransactionsをfire-and-forgetで呼ぶ）
      controller.updateFilter(newFilter);

      expect(controller.filter.type, TransactionFilterType.income);
      expect(controller.filter.startDate, DateTime(2026, 4, 1));
      expect(controller.filter.endDate, DateTime(2026, 4, 30));
      // 非同期のfetchが走っているのでisLoadingになる
      expect(controller.isLoading, isTrue);
    });

    test('updateFilter で同じフィルタを渡した場合は何もしない', () {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );

      // リスナーを追加
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      // 同じフィルタでupdateFilter
      controller.updateFilter(controller.filter);

      // 通知が発生しない（＝fetchTransactionsが呼ばれていない）
      expect(notifyCount, 0);
    });

    // ── refetch ────────────────────────────────

    test('refetch は現在のフィルタで再取得する', () async {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );

      // fetchTransactions（＝refetch）を直接呼ぶ
      await controller.refetch();

      expect(controller.transactions.length, 2);
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
    });

    // ── hasData ────────────────────────────────

    test('hasData: データありの場合はtrue', () async {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );

      await controller.fetchTransactions();
      expect(controller.hasData, isTrue);
    });

    test('hasData: 未fetch時はfalse', () {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );
      expect(controller.hasData, isFalse);
    });

    test('hasData: エラー時はfalse', () async {
      final controller = TransactionController(
        service: TransactionService(client: _errorMockClient()),
      );

      await controller.fetchTransactions();
      expect(controller.hasData, isFalse);
    });

    // ── isEmpty ────────────────────────────────

    test('isEmpty: ロード完了後データゼロの場合はtrue', () async {
      final emptyMockClient = MockClient((request) async {
        return _okResponse({'data': []});
      });

      final controller = TransactionController(
        service: TransactionService(client: emptyMockClient),
      );

      await controller.fetchTransactions();
      expect(controller.isEmpty, isTrue);
      expect(controller.hasData, isFalse);
    });

    test('isEmpty: 未fetch時はfalse', () {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );
      expect(controller.isEmpty, isFalse);
    });

    // ── dispose ────────────────────────────────

    test('dispose で service.dispose が呼ばれる', () {
      final client = _DisposeTrackingMockClient();
      final service = TransactionService(client: client);
      final controller = TransactionController(service: service);

      controller.dispose();
      expect(client.closed, isTrue);
    });

    // ── 複数回fetchの冪等性 ────────────────────

    test('fetchTransactions を複数回呼んでも正しく動作する', () async {
      int callCount = 0;
      final countingMockClient = MockClient((request) async {
        callCount++;
        return _okResponse({
          'data': [
            {'amount': callCount * 1000, 'purpose': 'test$callCount', 'category': 'その他', 'datetime': '2026-06-23T00:00:00'},
          ],
        });
      });

      final controller = TransactionController(
        service: TransactionService(client: countingMockClient),
      );

      await controller.fetchTransactions();
      expect(callCount, 1);
      expect(controller.transactions[0].amount, 1000);

      await controller.fetchTransactions();
      expect(callCount, 2);
      expect(controller.transactions[0].amount, 2000);
    });

    // ── transactions は不変リスト ──────────────

    test('transactions getter の戻り値は変更不可', () async {
      final controller = TransactionController(
        service: TransactionService(client: _successMockClient()),
      );

      await controller.fetchTransactions();
      final list = controller.transactions;

      final tx = list[0];
      expect(() { list.add(tx); }, throwsUnsupportedError);
    });
  });
}

/// dispose検出用のテストクライアント
class _DisposeTrackingMockClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.fromIterable([]),
      200,
    );
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

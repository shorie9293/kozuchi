import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/features/transaction_filter/domain/models/transaction_filter.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';

/// UTF-8のレスポンスを生成するヘルパー（日本語文字対応）
http.Response _ok(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('TransactionService', () {
    // ── 正常系: 全件フィルタ ──────────────────────

    test('全件フィルタでAPIから取引一覧を取得できる', () async {
      final mockClient = MockClient((request) async {
        final uri = request.url;
        // type=all の場合はクエリパラメータに type が含まれない
        expect(uri.queryParameters.containsKey('type'), isFalse);
        expect(uri.queryParameters['start_date'], '2026-06-01');
        expect(uri.queryParameters['end_date'], '2026-06-23');

        return _ok({
          'data': [
            {'amount': 50000, 'purpose': 'kyuyo', 'category': 'income', 'datetime': '2026-06-23T10:00:00'},
            {'amount': -3000, 'purpose': 'food', 'category': 'food', 'datetime': '2026-06-23T12:00:00'},
          ],
        });
      });

      final service = TransactionService(client: mockClient);
      final filter = TransactionFilter(
        type: TransactionFilterType.all,
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 23),
      );

      final result = await service.fetchTransactions(filter: filter);
      expect(result.length, 2);
      expect(result[0].amount, 50000);
      expect(result[0].purpose, 'kyuyo');
      expect(result[1].amount, -3000);
      expect(result[1].purpose, 'food');
    });

    // ── 正常系: 収入フィルタ ──────────────────────

    test('収入フィルタで type=income がクエリに含まれる', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['type'], 'income');
        return _ok({'data': []});
      });

      final service = TransactionService(client: mockClient);
      final filter = TransactionFilter(type: TransactionFilterType.income);

      final result = await service.fetchTransactions(filter: filter);
      expect(result, isEmpty);
    });

    // ── 正常系: 支出フィルタ ──────────────────────

    test('支出フィルタで type=expense がクエリに含まれる', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['type'], 'expense');
        return _ok({'data': []});
      });

      final service = TransactionService(client: mockClient);
      final filter = TransactionFilter(type: TransactionFilterType.expense);

      final result = await service.fetchTransactions(filter: filter);
      expect(result, isEmpty);
    });

    // ── 正常系: 日付範囲なし ──────────────────────

    test('日付範囲なしの場合はstart_date/end_dateがクエリに含まれない', () async {
      final mockClient = MockClient((request) async {
        final queryParams = request.url.queryParameters;
        expect(queryParams.containsKey('start_date'), isFalse);
        expect(queryParams.containsKey('end_date'), isFalse);
        return _ok({
          'data': [
            {'amount': 50000, 'purpose': 'kyuyo', 'category': 'income', 'datetime': '2026-06-23T10:00:00'},
          ],
        });
      });

      final service = TransactionService(client: mockClient);
      final filter = const TransactionFilter();

      final result = await service.fetchTransactions(filter: filter);
      expect(result.length, 1);
    });

    // ── 日付フォーマット ──────────────────────────

    test('日付がYYYY-MM-DD形式で整形される', () async {
      String? capturedStartDate;
      String? capturedEndDate;

      final mockClient = MockClient((request) async {
        capturedStartDate = request.url.queryParameters['start_date'];
        capturedEndDate = request.url.queryParameters['end_date'];
        return _ok({'data': []});
      });

      final service = TransactionService(client: mockClient);
      final filter = TransactionFilter(
        startDate: DateTime(2026, 1, 5),
        endDate: DateTime(2026, 12, 25),
      );

      await service.fetchTransactions(filter: filter);
      expect(capturedStartDate, '2026-01-05');
      expect(capturedEndDate, '2026-12-25');
    });

    // ── エラー系: 非200ステータス ──────────────────

    test('APIが200以外を返した場合はTransactionServiceExceptionを投げる', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(utf8.encode('Internal Server Error'), 500);
      });

      final service = TransactionService(client: mockClient);
      final filter = const TransactionFilter();

      expect(
        () => service.fetchTransactions(filter: filter),
        throwsA(isA<TransactionServiceException>()),
      );
    });

    // ── エラー系: データフィールド欠落 ─────────────

    test('レスポンスにdataフィールドがない場合はTransactionServiceExceptionを投げる', () async {
      final mockClient = MockClient((request) async {
        return _ok({'items': []}); // "data" ではなく "items"
      });

      final service = TransactionService(client: mockClient);
      final filter = const TransactionFilter();

      expect(
        () => service.fetchTransactions(filter: filter),
        throwsA(isA<TransactionServiceException>()),
      );
    });

    // ── エラー系: 不正JSON ────────────────────────

    test('不正なJSONレスポンスはTransactionServiceExceptionを投げる', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(utf8.encode('not json'), 200);
      });

      final service = TransactionService(client: mockClient);
      final filter = const TransactionFilter();

      expect(
        () => service.fetchTransactions(filter: filter),
        throwsA(isA<TransactionServiceException>()),
      );
    });

    // ── エラー系: ネットワークエラー ───────────────

    test('ネットワークエラーはTransactionServiceExceptionを投げる', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final service = TransactionService(client: mockClient);
      final filter = const TransactionFilter();

      expect(
        () => service.fetchTransactions(filter: filter),
        throwsA(isA<TransactionServiceException>()),
      );
    });

    // ── カスタムbaseUrl ─────────────────────────

    test('カスタムbaseUrlが使用される', () async {
      String? host;

      final mockClient = MockClient((request) async {
        host = request.url.host;
        return _ok({'data': []});
      });

      final service = TransactionService(
        client: mockClient,
        baseUrl: 'https://api.example.com',
      );
      final filter = const TransactionFilter();

      await service.fetchTransactions(filter: filter);
      expect(host, 'api.example.com');
    });

    // ── dispose ─────────────────────────────────

    test('disposeでクライアントがクローズされる', () {
      bool closed = false;
      final client = _CloseDetectingClient(() => closed = true);
      final service = TransactionService(client: client);
      service.dispose();
      expect(closed, isTrue);
    });
  });
}

/// dispose呼び出しを検出するためのテスト用クライアント
class _CloseDetectingClient extends http.BaseClient {
  final void Function() onClose;
  _CloseDetectingClient(this.onClose);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.fromIterable([utf8.encode(jsonEncode({'data': []}))]),
      200,
    );
  }

  @override
  void close() {
    onClose();
    super.close();
  }
}

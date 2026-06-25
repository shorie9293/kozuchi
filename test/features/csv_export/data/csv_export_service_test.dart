import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/features/csv_export/data/csv_export_service.dart';

void main() {
  /// UTF-8でエンコードされたCSVサンプル
  final sampleCsvContent = utf8.encode(
    'date,description,category,amount\n'
    '2026-06-23,給与,収入,50000\n'
    '2026-06-23,食費,食費,-3000\n',
  );

  group('CsvExportService', () {
    // ── 正常系: 日付範囲あり ────────────────────

    test('日付範囲指定でCSVを取得できる', () async {
      final mockClient = MockClient((request) async {
        final uri = request.url;
        expect(uri.queryParameters['start_date'], '2026-06-01');
        expect(uri.queryParameters['end_date'], '2026-06-23');

        return http.Response.bytes(sampleCsvContent, 200,
            headers: {'content-type': 'text/csv; charset=utf-8'});
      });

      final service = CsvExportService(client: mockClient);

      final result = await service.exportCsv(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 23),
      );

      expect(result, contains('date,description,category,amount'));
      expect(result, contains('2026-06-23,給与,収入,50000'));
      expect(result, contains('2026-06-23,食費,食費,-3000'));
    });

    // ── 正常系: 日付範囲なし ────────────────────

    test('日付範囲なしで全期間のCSVを取得できる', () async {
      final mockClient = MockClient((request) async {
        final queryParams = request.url.queryParameters;
        expect(queryParams.containsKey('start_date'), isFalse);
        expect(queryParams.containsKey('end_date'), isFalse);

        return http.Response.bytes(sampleCsvContent, 200,
            headers: {'content-type': 'text/csv; charset=utf-8'});
      });

      final service = CsvExportService(client: mockClient);

      final result = await service.exportCsv();
      expect(result, isNotEmpty);
    });

    // ── 正常系: startDateのみ ────────────────────

    test('startDateのみ指定でCSVを取得できる', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['start_date'], '2026-01-01');
        expect(request.url.queryParameters.containsKey('end_date'), isFalse);

        return http.Response.bytes(sampleCsvContent, 200,
            headers: {'content-type': 'text/csv; charset=utf-8'});
      });

      final service = CsvExportService(client: mockClient);

      final result = await service.exportCsv(startDate: DateTime(2026, 1, 1));
      expect(result, isNotEmpty);
    });

    // ── 正常系: endDateのみ ────────────────────

    test('endDateのみ指定でCSVを取得できる', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters.containsKey('start_date'), isFalse);
        expect(request.url.queryParameters['end_date'], '2026-12-31');

        return http.Response.bytes(sampleCsvContent, 200,
            headers: {'content-type': 'text/csv; charset=utf-8'});
      });

      final service = CsvExportService(client: mockClient);

      final result = await service.exportCsv(endDate: DateTime(2026, 12, 31));
      expect(result, isNotEmpty);
    });

    // ── 日付フォーマット ─────────────────────────

    test('日付がYYYY-MM-DD形式で整形される', () async {
      String? capturedStart;
      String? capturedEnd;

      final mockClient = MockClient((request) async {
        capturedStart = request.url.queryParameters['start_date'];
        capturedEnd = request.url.queryParameters['end_date'];
        return http.Response.bytes(sampleCsvContent, 200,
            headers: {'content-type': 'text/csv; charset=utf-8'});
      });

      final service = CsvExportService(client: mockClient);
      await service.exportCsv(
        startDate: DateTime(2026, 1, 5),
        endDate: DateTime(2026, 12, 25),
      );

      expect(capturedStart, '2026-01-05');
      expect(capturedEnd, '2026-12-25');
    });

    // ── エラー系: 400 Bad Request ───────────────

    test('APIが400を返した場合はCsvExportExceptionを投げる', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Invalid date format', 400);
      });

      final service = CsvExportService(client: mockClient);

      expect(
        () => service.exportCsv(
          startDate: DateTime(2026, 13, 1), // 不正な日付
        ),
        throwsA(isA<CsvExportException>()),
      );
    });

    // ── エラー系: 500 Internal Server Error ─────

    test('APIが500を返した場合はCsvExportExceptionを投げる', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = CsvExportService(client: mockClient);

      expect(
        () => service.exportCsv(),
        throwsA(isA<CsvExportException>()),
      );
    });

    // ── エラー系: ネットワークエラー ──────────────

    test('ネットワークエラーはCsvExportExceptionを投げる', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final service = CsvExportService(client: mockClient);

      expect(
        () => service.exportCsv(),
        throwsA(isA<CsvExportException>()),
      );
    });

    // ── カスタムbaseUrl ─────────────────────────

    test('カスタムbaseUrlが使用される', () async {
      String? host;

      final mockClient = MockClient((request) async {
        host = request.url.host;
        return http.Response.bytes(sampleCsvContent, 200,
            headers: {'content-type': 'text/csv; charset=utf-8'});
      });

      final service = CsvExportService(
        client: mockClient,
        baseUrl: 'https://api.example.com',
      );

      await service.exportCsv();
      expect(host, 'api.example.com');
    });

    // ── dispose ─────────────────────────────────

    test('disposeでクライアントがクローズされる', () {
      bool closed = false;
      final client = _CloseDetectingClient(() => closed = true);
      final service = CsvExportService(client: client);
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
      Stream.fromIterable([utf8.encode('date,category,amount\n')]),
      200,
      headers: {'content-type': 'text/csv; charset=utf-8'},
    );
  }

  @override
  void close() {
    onClose();
    super.close();
  }
}

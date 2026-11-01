import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/features/weekly_report/data/weekly_report_api_service.dart';

void main() {
  group('WeeklyReportApiService のタイムアウト', () {
    test('fetchReport は時間切れを isTimeout 付きの例外で返す', () async {
      var calls = 0;
      final service = WeeklyReportApiService(
        baseUrl: 'https://example.invalid',
        client: MockClient((request) {
          calls++;
          return Completer<http.Response>().future;
        }),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.fetchReport(),
        throwsA(
          isA<WeeklyReportApiException>()
              .having((e) => e.isTimeout, 'isTimeout', isTrue),
        ),
      );
      expect(calls, 1);
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/domain/models/achievement_check_models.dart';
import 'package:kozuchi/features/achievements/data/achievement_service.dart';

/// 応答を一切返さない（圏外・無応答を模した）クライアント。
http.Client hangingClient(void Function() onCall) {
  return MockClient((request) {
    onCall();
    return Completer<http.Response>().future;
  });
}

void main() {
  group('AchievementService のタイムアウト', () {
    test('fetchAchievements は時間切れを isTimeout 付きの例外で返す', () async {
      var calls = 0;
      final service = AchievementService(
        baseUrl: 'https://example.invalid',
        client: hangingClient(() => calls++),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.fetchAchievements(),
        throwsA(
          isA<AchievementServiceException>()
              .having((e) => e.isTimeout, 'isTimeout', isTrue),
        ),
      );
      expect(calls, 1, reason: '自動リトライはしない（再試行は利用者の操作）');
    });

    test('checkAchievements も時間切れで失敗する', () async {
      final service = AchievementService(
        baseUrl: 'https://example.invalid',
        client: hangingClient(() {}),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.checkAchievements(
          const AchievementCheckRequest(userId: 'u1'),
        ),
        throwsA(
          isA<AchievementServiceException>()
              .having((e) => e.isTimeout, 'isTimeout', isTrue),
        ),
      );
    });

    test('応答が返ればタイムアウトは発火しない（既存経路の回帰）', () async {
      final service = AchievementService(
        baseUrl: 'https://example.invalid',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(<dynamic>[]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        timeout: const Duration(milliseconds: 50),
      );

      expect(await service.fetchAchievements(), isEmpty);
    });
  });
}

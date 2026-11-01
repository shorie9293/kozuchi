import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/features/goals/data/goal_api_service.dart';

/// 応答を一切返さない（圏外・無応答を模した）クライアント。
http.Client hangingClient(void Function() onCall) {
  return MockClient((request) {
    onCall();
    return Completer<http.Response>().future;
  });
}

void main() {
  group('GoalApiService のタイムアウト', () {
    GoalApiService build(void Function() onCall) => GoalApiService(
          baseUrl: 'https://example.invalid',
          client: hangingClient(onCall),
          timeout: const Duration(milliseconds: 50),
        );

    test('listGoals は時間切れを isTimeout 付きの例外で返す', () async {
      var calls = 0;
      await expectLater(
        build(() => calls++).listGoals(),
        throwsA(
          isA<GoalApiException>()
              .having((e) => e.isTimeout, 'isTimeout', isTrue),
        ),
      );
      expect(calls, 1, reason: '自動リトライはしない');
    });

    test('getGoal も時間切れで失敗する', () async {
      await expectLater(
        build(() {}).getGoal('g1'),
        throwsA(isA<GoalApiException>()
            .having((e) => e.isTimeout, 'isTimeout', isTrue)),
      );
    });

    test('createGoal も時間切れで失敗する', () async {
      await expectLater(
        build(() {}).createGoal(title: '積立', targetAmount: 1000),
        throwsA(isA<GoalApiException>()
            .having((e) => e.isTimeout, 'isTimeout', isTrue)),
      );
    });

    test('updateGoal も時間切れで失敗する', () async {
      await expectLater(
        build(() {}).updateGoal('g1', currentAmount: 500),
        throwsA(isA<GoalApiException>()
            .having((e) => e.isTimeout, 'isTimeout', isTrue)),
      );
    });

    test('deleteGoal も時間切れで失敗する', () async {
      await expectLater(
        build(() {}).deleteGoal('g1'),
        throwsA(isA<GoalApiException>()
            .having((e) => e.isTimeout, 'isTimeout', isTrue)),
      );
    });

    test('応答が返ればタイムアウトは発火しない（既存経路の回帰）', () async {
      final service = GoalApiService(
        baseUrl: 'https://example.invalid',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'goals': <dynamic>[], 'total': 0}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        timeout: const Duration(milliseconds: 50),
      );

      final response = await service.listGoals();
      expect(response.total, 0);
    });
  });
}

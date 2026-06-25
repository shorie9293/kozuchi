import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/trial_quest/data/deepseek_review_service.dart';

/// テスト用のFake HTTPクライアント
class FakeHttpClient extends http.BaseClient {
  final Map<String, http.Response> responses;
  int callCount = 0;
  http.BaseRequest? lastRequest;

  FakeHttpClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    lastRequest = request;
    final uri = request.url.toString();
    final response = responses[uri];
    if (response != null) {
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"error": "not found"}')),
      404,
    );
  }
}

void main() {
  group('DeepSeekReviewService', () {
    late Map<String, http.Response> responses;
    late FakeHttpClient fakeClient;
    late DeepSeekReviewService service;

    const apiUrl = 'https://api.deepseek.com/v1/chat/completions';

    setUp(() {
      responses = {};
      fakeClient = FakeHttpClient(responses);
      service = DeepSeekReviewService(httpClient: fakeClient);
    });

    group('API呼び出し', () {
      test('正しいエンドポイントにPOSTリクエストを送信する', () async {
        responses[apiUrl] = http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '汝の内省は深い。よく励んだぞ。EXP: 1.5',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        expect(fakeClient.callCount, 1);
        expect(fakeClient.lastRequest!.method, 'POST');
        expect(fakeClient.lastRequest!.url.toString(), apiUrl);
      });

      test('リクエストヘッダーにBearerトークンが含まれる', () async {
        responses[apiUrl] = http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '汝の内省は深い。よく励んだぞ。EXP: 1.5',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        final authHeader = fakeClient.lastRequest!.headers['authorization'];
        expect(authHeader, isNotNull);
        expect(authHeader, startsWith('Bearer '));
      });

      test('リクエストボディにmodelとmessagesが含まれる', () async {
        responses[apiUrl] = http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '汝の内省は深い。よく励んだぞ。EXP: 1.5',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        final bodyBytes = await fakeClient.lastRequest!.finalize().toList();
        final bodyStr = utf8.decode(bodyBytes.expand((b) => b).toList());
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        expect(body['model'], 'deepseek-chat');
        expect(body['messages'], isA<List>());
        expect((body['messages'] as List).length, greaterThanOrEqualTo(2));
      });

      test('ユーザーメッセージに振り返り文と支出情報が含まれる', () async {
        responses[apiUrl] = http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '汝の内省は深い。よく励んだぞ。EXP: 1.5',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        final bodyBytes = await fakeClient.lastRequest!.finalize().toList();
        final bodyStr = utf8.decode(bodyBytes.expand((b) => b).toList());
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        final userMessage = messages.lastWhere(
          (m) => m['role'] == 'user',
        )['content'] as String;

        expect(userMessage, contains('相手が喜んでくれて嬉しかった'));
        expect(userMessage, contains('3000'));
        expect(userMessage, contains('友人との食事'));
      });
    });

    group('応答パース', () {
      test('EXP倍率をレスポンスからパースする', () async {
        responses[apiUrl] = http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '大黒天「よくぞ内省した。その気づきこそが福の種ぞ。EXP: 1.5」',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        final result = await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        expect(result.expMultiplier, 1.5);
      });

      test('EXP倍率が1.0の時も正しくパースする', () async {
        responses[apiUrl] = http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': 'ふむ、悪くない。EXP: 1.0',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        final result = await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        expect(result.expMultiplier, 1.0);
      });

      test('EXP倍率が2.0の時も正しくパースする', () async {
        responses[apiUrl] = http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '見事な内省だ！EXP: 2.0',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        final result = await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '深く内省しました',
          offeringAmount: 5000,
          offeringPurpose: '自己投資',
        );

        expect(result.expMultiplier, 2.0);
      });

      test('講評文が正しく抽出される', () async {
        final reviewText = '大黒天「うむ、その内省の中に確かな悟りの灯を見た。'
            '支出の痛みは執着の手放しに他ならぬ。よく励んだぞ。」';
        responses[apiUrl] = http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '$reviewText EXP: 1.2',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );

        final result = await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        expect(result.reviewText, reviewText);
      });
    });

    group('エラーハンドリング', () {
      test('ネットワークエラー時にフォールバック講評を返す', () async {
        // レスポンスを設定しない → 404エラー
        final result = await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        expect(result.reviewText, isNotEmpty);
        expect(result.reviewText, contains('大黒天'));
        expect(result.expMultiplier, 1.0);
      });

      test('JSONパースエラー時にフォールバック講評を返す', () async {
        responses[apiUrl] = http.Response(
          'invalid json',
          200,
          headers: {'content-type': 'application/json'},
        );

        final result = await service.generateReview(
          deity: Advisor.daikokuten,
          reflection: '相手が喜んでくれて嬉しかった',
          offeringAmount: 3000,
          offeringPurpose: '友人との食事',
        );

        expect(result.reviewText, isNotEmpty);
        expect(result.reviewText, contains('大黒天'));
        expect(result.expMultiplier, 1.0);
      });
    });
  });
}

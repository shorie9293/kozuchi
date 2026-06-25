import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/trial_quest/domain/ai_review_service.dart';

/// DeepSeek APIを使用した講評サービスの実装
///
/// 環境変数 DEEPSEEK_API_KEY からAPIキーを取得する。
class DeepSeekReviewService implements AiReviewService {
  final http.Client _httpClient;
  final String _apiKey;

  static const String _apiUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String _model = 'deepseek-chat';

  DeepSeekReviewService({
    http.Client? httpClient,
    String? apiKey,
  })  : _httpClient = httpClient ?? http.Client(),
        _apiKey = apiKey ?? _readApiKey();

  static String _readApiKey() {
    // 環境変数からAPIキーを読み取り
    const key = String.fromEnvironment('DEEPSEEK_API_KEY');
    if (key.isEmpty) {
      // 開発時はダミーキー（実際のAPI呼び出しは行われない想定）
      return 'dev-dummy-key';
    }
    return key;
  }

  /// アドバイザーのシステムプロンプトを構築する（パブリック：テスト用）
  String buildSystemPrompt(Advisor deity) {
    switch (deity) {
      case Advisor.daikokuten:
        return 'あなたは大黒天（だいこくてん）——福・食・財を司るアドバイザーである。'
            '打ち出の小槌を携え、支出（支出）の意味を悟った者に福を与える。'
            '語尾は「〜ぞ」「〜であろう」を用い、威厳あるが温かみのある口調で語れ。'
            'プレイヤーの振り返りに対し、仏教的視点から講評を述べよ。'
            '講評の末尾に「EXP: X.X」の形式で悟りの深さ評価'
            '（0.5〜2.0の数字）を必ず付与せよ。';
      case Advisor.benzaiten:
        return 'あなたは弁財天（べんざいてん）——学び・芸術・智慧を司るアドバイザーである。'
            '琵琶を奏で、知識の支出を称える。'
            '語尾は「〜わ」「〜でしょう」を用い、優雅で知的な口調で語れ。'
            'プレイヤーの振り返りに対し、学びの視点から講評を述べよ。'
            '講評の末尾に「EXP: X.X」の形式で悟りの深さ評価'
            '（0.5〜2.0の数字）を必ず付与せよ。';
      case Advisor.bishamonten:
        return 'あなたは毘沙門天（びしゃもんてん）——戦い・勝負・自己投資を司るアドバイザーである。'
            '槍を掲げ、己への投資の価値を説く。'
            '語尾は「〜だ」「〜であろう」を用い、武人的で力強い口調で語れ。'
            'プレイヤーの振り返りに対し、勝負の視点から講評を述べよ。'
            '講評の末尾に「EXP: X.X」の形式で悟りの深さ評価'
            '（0.5〜2.0の数字）を必ず付与せよ。';
      case Advisor.kichijoten:
        return 'あなたは吉祥天（きっしょうてん）——美・幸福・贈与を司るアドバイザーである。'
            '蓮の花を手に、与える喜びを祝福する。'
            '語尾は「〜なさい」「〜でしょう」を用い、慈愛に満ちた優しい口調で語れ。'
            'プレイヤーの振り返りに対し、幸福の視点から講評を述べよ。'
            '講評の末尾に「EXP: X.X」の形式で悟りの深さ評価'
            '（0.5〜2.0の数字）を必ず付与せよ。';
    }
  }

  /// ユーザーメッセージを構築する（パブリック：テスト用）
  String buildUserMessage({
    required String reflection,
    required int offeringAmount,
    required String offeringPurpose,
  }) {
    return '以下が本日の支出と振り返りである。\n\n'
        '【支出金額】$offeringAmount円\n'
        '【支出の用途】$offeringPurpose\n'
        '【振り返り】$reflection\n\n'
        'この振り返りに対し、講評を述べよ。';
  }

  @override
  Future<AiReviewResult> generateReview({
    required Advisor deity,
    required String reflection,
    required int offeringAmount,
    required String offeringPurpose,
  }) async {
    try {
      final systemPrompt = buildSystemPrompt(deity);
      final userMessage = buildUserMessage(
        reflection: reflection,
        offeringAmount: offeringAmount,
        offeringPurpose: offeringPurpose,
      );

      final requestBody = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
      });

      final response = await _httpClient.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        return _fallbackReview(deity);
      }

      // UTF-8デコード（Latin1問題対策）
      final bodyStr = utf8.decode(response.bodyBytes);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return _fallbackReview(deity);
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) {
        return _fallbackReview(deity);
      }

      return _parseResponse(content, deity);
    } catch (e) {
      return _fallbackReview(deity);
    }
  }

  /// DeepSeekの応答から講評文とEXP倍率をパースする
  AiReviewResult _parseResponse(String content, Advisor deity) {
    // EXP倍率を抽出（"EXP: X.X" のパターン）
    final expRegex = RegExp(r'EXP:\s*(\d+\.?\d*)', caseSensitive: false);
    final match = expRegex.firstMatch(content);

    double multiplier = 1.0;
    if (match != null) {
      final value = double.tryParse(match.group(1)!);
      if (value != null) {
        // 0.5〜2.0 の範囲に制限
        multiplier = value.clamp(0.5, 2.0);
      }
    }

    // EXP評価文を除去した講評文
    final reviewText = content.replaceAll(expRegex, '').trim();

    return AiReviewResult(
      reviewText: reviewText,
      expMultiplier: multiplier,
    );
  }

  /// APIエラー時のフォールバック講評
  AiReviewResult _fallbackReview(Advisor deity) {
    return AiReviewResult(
      reviewText: '${deity.label}「うむ、その行いは確かに我が目に留まった。'
          'されど今はこれ以上の言葉を紡ぐ時ではない。'
          'また次の試練で会おう。」',
      expMultiplier: 1.0,
    );
  }

  /// HTTPクライアントを破棄する
  void dispose() {
    _httpClient.close();
  }
}

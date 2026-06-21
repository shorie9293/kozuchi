import 'package:kozuchi/domain/models/advisor.dart';

/// AI講評サービスの抽象インターフェース
///
/// アドバイザーによる試練講評（LLM生成）のための抽象化。
/// Mock / DeepSeek / 他LLM の切り替えが可能。
abstract class AiReviewService {
  /// 振り返り文からアドバイザーの講評を生成する
  ///
  /// [deity] アドバイザー
  /// [reflection] プレイヤーの振り返り文
  /// [offeringAmount] 支出金額（円）
  /// [offeringPurpose] 支出の用途
  /// 戻り値: [AiReviewResult]（講評文 + EXP倍率）
  Future<AiReviewResult> generateReview({
    required Advisor deity,
    required String reflection,
    required int offeringAmount,
    required String offeringPurpose,
  });
}

/// AI講評の結果
class AiReviewResult {
  /// アドバイザーによる講評文
  final String reviewText;

  /// EXP基本値にかける倍率（0.5〜2.0）
  final double expMultiplier;

  const AiReviewResult({
    required this.reviewText,
    required this.expMultiplier,
  });
}

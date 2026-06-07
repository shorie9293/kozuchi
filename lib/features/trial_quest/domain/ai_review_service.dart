import 'package:kozuchi/domain/models/guardian_deity.dart';

/// AI講評サービスの抽象インターフェース
///
/// 守護神による試練講評（LLM生成）のための抽象化。
/// Mock / DeepSeek / 他LLM の切り替えが可能。
abstract class AiReviewService {
  /// 振り返り文から守護神の講評を生成する
  ///
  /// [deity] 守護神
  /// [reflection] プレイヤーの振り返り文
  /// [offeringAmount] 喜捨金額（円）
  /// [offeringPurpose] 喜捨の用途
  /// 戻り値: [AiReviewResult]（講評文 + SATORI倍率）
  Future<AiReviewResult> generateReview({
    required GuardianDeity deity,
    required String reflection,
    required int offeringAmount,
    required String offeringPurpose,
  });
}

/// AI講評の結果
class AiReviewResult {
  /// 守護神による講評文
  final String reviewText;

  /// SATORI基本値にかける倍率（0.5〜2.0）
  final double satoriMultiplier;

  const AiReviewResult({
    required this.reviewText,
    required this.satoriMultiplier,
  });
}

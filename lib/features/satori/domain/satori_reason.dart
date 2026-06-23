import 'package:kozuchi/domain/models/level_stage.dart';

/// SATORI変動の文脈情報
///
/// 変動理由の判定に必要なメタデータを保持する。
class SatoriContext {
  /// 変動の契機
  final SatoriTriggerType triggerType;

  /// アドバイザー表示名（例: "ライフプランナー"）
  final String? advisorLabel;

  /// AI講評によるEXP倍率（0.5〜2.0）
  final double? expMultiplier;

  /// 支出金額（円）
  final int? offeringAmount;

  /// 変動前の開眼段階
  final LevelStage? previousStage;

  /// 変動後の開眼段階
  final LevelStage? newStage;

  const SatoriContext({
    this.triggerType = SatoriTriggerType.generic,
    this.advisorLabel,
    this.expMultiplier,
    this.offeringAmount,
    this.previousStage,
    this.newStage,
  });

  /// 振り返り講評からの変動
  factory SatoriContext.reflectionReview({
    String? advisorLabel,
    double? expMultiplier,
    int? offeringAmount,
    LevelStage? previousStage,
    LevelStage? newStage,
  }) {
    return SatoriContext(
      triggerType: SatoriTriggerType.reflectionReview,
      advisorLabel: advisorLabel,
      expMultiplier: expMultiplier,
      offeringAmount: offeringAmount,
      previousStage: previousStage,
      newStage: newStage,
    );
  }

  /// キャリアコーチボーナスからの変動
  factory SatoriContext.careerCoachBonus({
    String? bookTitle,
    LevelStage? previousStage,
    LevelStage? newStage,
  }) {
    return SatoriContext(
      triggerType: SatoriTriggerType.careerCoachBonus,
      advisorLabel: bookTitle != null ? 'キャリアコーチ（$bookTitle）' : 'キャリアコーチ',
      previousStage: previousStage,
      newStage: newStage,
    );
  }

  /// 汎用変動
  factory SatoriContext.generic({
    LevelStage? previousStage,
    LevelStage? newStage,
  }) {
    return SatoriContext(
      triggerType: SatoriTriggerType.generic,
      previousStage: previousStage,
      newStage: newStage,
    );
  }
}

/// SATORI変動の契機種別
enum SatoriTriggerType {
  /// 振り返り講評
  reflectionReview,

  /// キャリアコーチボーナス
  careerCoachBonus,

  /// ピンチゾーンペナルティ（将来実装）
  pinchPenalty,

  /// その他
  generic,
}

/// SATORI変動の理由文字列を生成する
///
/// 変動の文脈（[SatoriContext]）から、人間が読める日本語の理由文字列を判定する。
class SatoriReason {
  const SatoriReason._();

  /// 増加時の理由を判定する
  ///
  /// [context] の内容に基づき、最も適切な理由文字列を返す。
  static String forIncrease(SatoriContext context) {
    // 段階突破を最優先でチェック
    if (context.previousStage != null && context.newStage != null) {
      if (context.previousStage != context.newStage) {
        return _stageUpReason(context.newStage!);
      }
    }

    // 振り返り講評の場合
    if (context.triggerType == SatoriTriggerType.reflectionReview) {
      return _reflectionReviewIncreaseReason(context);
    }

    // キャリアコーチボーナス
    if (context.triggerType == SatoriTriggerType.careerCoachBonus) {
      return '智慧の蔵書ボーナス';
    }

    // 汎用
    return '悟りの一歩';
  }

  /// 減少時の理由を判定する
  static String forDecrease(SatoriContext context) {
    if (context.triggerType == SatoriTriggerType.pinchPenalty) {
      return '金銭感覚の乱れ';
    }
    return '執着の逆戻り';
  }

  /// 振り返り講評からの増加理由
  static String _reflectionReviewIncreaseReason(SatoriContext context) {
    final multiplier = context.expMultiplier ?? 1.0;
    final amount = context.offeringAmount ?? 0;

    // 深い内省（高倍率）
    if (multiplier >= 1.8) {
      return '深き内省の悟り';
    }
    if (multiplier >= 1.3) {
      return '善き振り返りの恵み';
    }

    // 大口の支出
    if (amount >= 10000) {
      return '惜しみなき喜捨';
    }
    if (amount >= 5000) {
      return '気前よき布施';
    }

    // 浅い内省（低倍率）
    if (multiplier <= 0.7) {
      return '無駄遣いの自覚';
    }

    // デフォルト
    return '善き布施の実践';
  }

  /// 段階突破の理由
  static String _stageUpReason(LevelStage newStage) {
    switch (newStage) {
      case LevelStage.engi:
        return '新たな開眼 — 金は縁として巡る';
      case LevelStage.kuu:
        return '究極の悟り — 所有の幻を見破る';
      case LevelStage.shoTenborin:
        return '悟りの始まり';
    }
  }
}

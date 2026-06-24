import 'package:kozuchi/domain/streak/streak.dart';

/// ストリークサービス
///
/// ストリークの EXP 倍率計算、飢餓地帯管理、復帰任務の統合窓口。
class StreakService {
  /// ストリーク日数に基づく EXP 倍率を返す（純粋関数・副作用なし）。
  ///
  /// | ストリーク日数 | 倍率 |
  /// |--------------|------|
  /// | 30日以上      | 2.0x |
  /// | 14日以上      | 1.5x |
  /// | 7日以上       | 1.2x |
  /// | 7日未満       | 1.0x |
  static double calcExpMultiplier(int streakDays) {
    if (streakDays >= 30) return 2.0;
    if (streakDays >= 14) return 1.5;
    if (streakDays >= 7) return 1.2;
    return 1.0;
  }

  /// ストリークボーナスを適用した EXP 値を計算する。
  ///
  /// [baseExp] は基本 EXP、[streakDays] は現在のストリーク日数。
  /// 戻り値は [baseExp] × [calcExpMultiplier] を四捨五入した整数。
  static int calcBoostedExp(int baseExp, int streakDays) {
    return (baseExp * calcExpMultiplier(streakDays)).round();
  }

  /// 飢餓地帯のペナルティ倍率を返す。
  ///
  /// [hungryZone] が発動中の場合、その statMultiplier を返す。
  /// 未発動の場合は 1.0。
  static double calcStatMultiplier(HungryZone hungryZone) {
    return hungryZone.currentStatMultiplier;
  }

  /// 現在の総合 EXP 倍率を計算する。
  ///
  /// ストリークボーナスと飢餓地帯ペナルティの両方を考慮した倍率を返す。
  /// 例: ストリーク30日(2.0x) × 飢餓地帯(0.7) = 1.4x
  static double calcTotalExpMultiplier(int streakDays, HungryZone hungryZone) {
    final streakMult = calcExpMultiplier(streakDays);
    final statMult = calcStatMultiplier(hungryZone);
    return streakMult * statMult;
  }
}

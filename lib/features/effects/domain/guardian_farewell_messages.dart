import 'package:kozuchi/domain/models/advisor.dart';

/// 守護神切替時の別れの言葉
///
/// 各アドバイザーが去る際に表示する別れのメッセージ。
class GuardianFarewellMessages {
  const GuardianFarewellMessages._();

  /// 指定されたアドバイザーの別れの言葉を取得する
  static String farewell(Advisor advisor) {
    return switch (advisor) {
      Advisor.lifePlanner =>
        '「福と財の加護、忘るるなかれ。日々の糧を大切に」',
      Advisor.careerCoach =>
        '「学びの灯は汝の中にあり。我が去りても、道を求め続けよ」',
      Advisor.investmentMentor =>
        '「戦いの日々に幸いあれ。汝の武運が未来を拓く」',
      Advisor.wellnessAdvisor =>
        '「美しき日々よ、さらば。汝の幸福が咲き誇らんことを」',
    };
  }

  /// 新しい守護神との契約の言葉
  static String contractGreeting(Advisor advisor) {
    return switch (advisor) {
      Advisor.lifePlanner =>
        '新たなる加護、ライフプランナーと契約を結んだ！',
      Advisor.careerCoach =>
        '新たなる加護、キャリアコーチと契約を結んだ！',
      Advisor.investmentMentor =>
        '新たなる加護、投資メンターと契約を結んだ！',
      Advisor.wellnessAdvisor =>
        '新たなる加護、ウェルネスアドバイザーと契約を結んだ！',
    };
  }
}

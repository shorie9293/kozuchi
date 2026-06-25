import 'package:kozuchi/domain/models/advisor.dart';

/// 守護神切替時の別れの言葉
///
/// 各守護神が去る際に表示する別れのメッセージ。
class GuardianFarewellMessages {
  const GuardianFarewellMessages._();

  /// 指定された守護神の別れの言葉を取得する
  static String farewell(Advisor advisor) {
    return switch (advisor) {
      Advisor.daikokuten =>
        '「福と財の加護、忘るるなかれ。日々の糧を大切に」',
      Advisor.benzaiten =>
        '「学びの灯は汝の中にあり。我が去りても、道を求め続けよ」',
      Advisor.bishamonten =>
        '「戦いの日々に幸いあれ。汝の武運が未来を拓く」',
      Advisor.kichijoten =>
        '「美しき日々よ、さらば。汝の幸福が咲き誇らんことを」',
    };
  }

  /// 新しい守護神との契約の言葉
  static String contractGreeting(Advisor advisor) {
    return switch (advisor) {
      Advisor.daikokuten =>
        '新たなる加護、大黒天と契約を結んだ！',
      Advisor.benzaiten =>
        '新たなる加護、弁財天と契約を結んだ！',
      Advisor.bishamonten =>
        '新たなる加護、毘沙門天と契約を結んだ！',
      Advisor.kichijoten =>
        '新たなる加護、吉祥天と契約を結んだ！',
    };
  }
}

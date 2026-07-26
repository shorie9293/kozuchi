/// 試練クエストの悟りEXP算出ロジック
///
/// 支出クエスト完了時のEXP獲得量を、支出額・AI講評倍率・
/// 契約中の守護神（アドバイザー）の加護倍率から算出する。
/// 純関数として切り出すことで単体試験が可能。

/// 試練クエストの悟りEXP獲得量を計算する。
///
/// [offeringAmount] 支出金額（円）。0以下の場合は0を返す。
/// [aiMultiplier] AI講評による内省深さ倍率（通常 0.5〜2.0）。
/// [advisorMultiplier] 契約中の守護神の加護倍率（通常 1.0〜1.2）。
int calculateQuestExpGain({
  required int offeringAmount,
  required double aiMultiplier,
  required double advisorMultiplier,
}) {
  if (offeringAmount <= 0) return 0;
  final base = 5 + (offeringAmount / 1000).floor();
  return (base * aiMultiplier * advisorMultiplier).round();
}

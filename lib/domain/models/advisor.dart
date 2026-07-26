/// 四天アドバイザー（守護神）
///
/// プレイヤーが契約する四柱の守護神。
/// 各神は異なる領分と試練を持ち、契約すると支出クエストの悟りEXPに
/// それぞれ定められた加護（[expMultiplier]）が適用される。
enum Advisor {
  daikokuten(
    label: '大黒天',
    domain: '福・食・財',
    emoji: '🪘',
    role: '日々の糧と富を司る福の神',
    effect: '食費・日用品の支出で確かな悟りを得る',
    blessing: '支出クエストの悟りEXP ＋0%',
    trialStyle: '威厳ある温かな講評',
    expMultiplier: 1.0,
  ),
  benzaiten(
    label: '弁財天',
    domain: '学び・芸術',
    emoji: '🎵',
    role: '智慧と芸術を司る弁才の神',
    effect: '学び・書籍の支出で深い悟りを得る',
    blessing: '支出クエストの悟りEXP ＋10%',
    trialStyle: '優雅で知的な講評',
    expMultiplier: 1.1,
  ),
  bishamonten(
    label: '毘沙門天',
    domain: '戦い・勝負',
    emoji: '⚔️',
    role: '勝負と己への投資を司る武神',
    effect: '自己投資・勝負の支出で最大の悟りを得る',
    blessing: '支出クエストの悟りEXP ＋20%',
    trialStyle: '武人的で力強い講評',
    expMultiplier: 1.2,
  ),
  kichijoten(
    label: '吉祥天',
    domain: '美・幸福',
    emoji: '🌸',
    role: '美と幸福を司る慈愛の女神',
    effect: '美・幸福の支出で穏やかな悟りを得る',
    blessing: '支出クエストの悟りEXP ＋0%',
    trialStyle: '慈愛に満ちた講評',
    expMultiplier: 1.0,
  );

  const Advisor({
    required this.label,
    required this.domain,
    required this.emoji,
    required this.role,
    required this.effect,
    required this.blessing,
    required this.trialStyle,
    required this.expMultiplier,
  });

  /// 守護神の名前（例：大黒天）
  final String label;

  /// 守護神が掌る領分
  final String domain;

  /// 表示用絵文字
  final String emoji;

  /// 守護神の役割（一言で表す「意味」）
  final String role;

  /// 契約による試練上の効果の簡潔な説明
  final String effect;

  /// 契約による具体的な加護（機能的影響の説明）
  final String blessing;

  /// 講評の文体
  final String trialStyle;

  /// EXP倍率（1.0 = 等倍, 1.2 = 20%上昇）
  ///
  /// 支出クエストの悟りEXP算出に適用される。
  /// これが守護神選択の最大の「意味」＝機能的影響である。
  final double expMultiplier;

  /// EXP倍率を表示用テキストに変換（例: "x1.0", "x1.2"）
  String get expMultiplierText => 'x${expMultiplier.toStringAsFixed(1)}';
}

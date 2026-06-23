/// 四天アドバイザー
///
/// プレイヤーが契約する四柱のアドバイザー。
/// 各神は異なる領分と試練を持つ。
enum Advisor {
  lifePlanner(
    label: 'ライフプランナー',
    domain: '福・食・財',
    emoji: '🪘',
    effect: '食費・日用品の支出でEXP上昇',
    trialStyle: '威厳ある温かな講評',
    expMultiplier: 1.0,
  ),
  careerCoach(
    label: 'キャリアコーチ',
    domain: '学び・芸術',
    emoji: '🎵',
    effect: '学び・書籍の支出でEXP上昇',
    trialStyle: '優雅で知的な講評',
    expMultiplier: 1.1,
  ),
  investmentMentor(
    label: '投資メンター',
    domain: '戦い・勝負',
    emoji: '⚔️',
    effect: '自己投資・勝負の支出でEXP上昇',
    trialStyle: '武人的で力強い講評',
    expMultiplier: 1.2,
  ),
  wellnessAdvisor(
    label: 'ウェルネスアドバイザー',
    domain: '美・幸福',
    emoji: '🌸',
    effect: '美・幸福の支出でEXP上昇',
    trialStyle: '慈愛に満ちた講評',
    expMultiplier: 1.0,
  );

  const Advisor({
    required this.label,
    required this.domain,
    required this.emoji,
    required this.effect,
    required this.trialStyle,
    required this.expMultiplier,
  });

  /// アドバイザーの名前（例：ライフプランナー）
  final String label;

  /// アドバイザーが掌る領分
  final String domain;

  /// 表示用絵文字
  final String emoji;

  /// 契約による効果の簡潔な説明（例：食費・日用品の支出でEXP上昇）
  final String effect;

  /// 講評の文体（例：威厳ある温かな講評）
  final String trialStyle;

  /// EXP倍率（1.0 = 等倍, 1.2 = 20%上昇）
  final double expMultiplier;

  /// EXP倍率を表示用テキストに変換（例: "x1.0", "x1.2"）
  String get expMultiplierText => 'x${expMultiplier.toStringAsFixed(1)}';
}

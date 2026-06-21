/// 四天アドバイザー
///
/// プレイヤーが契約する四柱のアドバイザー。
/// 各神は異なる領分と試練を持つ。
enum Advisor {
  lifePlanner(
    label: 'ライフプランナー',
    domain: '福・食・財',
    emoji: '🪘',
  ),
  careerCoach(
    label: 'キャリアコーチ',
    domain: '学び・芸術',
    emoji: '🎵',
  ),
  investmentMentor(
    label: '投資メンター',
    domain: '戦い・勝負',
    emoji: '⚔️',
  ),
  wellnessAdvisor(
    label: 'ウェルネスアドバイザー',
    domain: '美・幸福',
    emoji: '🌸',
  );

  const Advisor({
    required this.label,
    required this.domain,
    required this.emoji,
  });

  /// アドバイザーの名前（例：ライフプランナー）
  final String label;

  /// アドバイザーが掌る領分
  final String domain;

  /// 表示用絵文字
  final String emoji;
}

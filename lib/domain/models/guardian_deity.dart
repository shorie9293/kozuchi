/// 四天守護神
///
/// プレイヤーが契約する四柱の守護神。
/// 各神は異なる領分と試練を持つ。
enum GuardianDeity {
  daikokuten(
    label: '大黒天',
    domain: '福・食・財',
    emoji: '🪘',
  ),
  benzaiten(
    label: '弁財天',
    domain: '学び・芸術',
    emoji: '🎵',
  ),
  bishamonten(
    label: '毘沙門天',
    domain: '戦い・勝負',
    emoji: '⚔️',
  ),
  kisshoten(
    label: '吉祥天',
    domain: '美・幸福',
    emoji: '🌸',
  );

  const GuardianDeity({
    required this.label,
    required this.domain,
    required this.emoji,
  });

  /// 守護神の名前（例：大黒天）
  final String label;

  /// 守護神が掌る領分
  final String domain;

  /// 表示用絵文字
  final String emoji;
}

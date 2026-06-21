/// 開眼の三段階
///
/// EXP（悟り）値に応じてプレイヤーの開眼段階が変化する。
enum LevelStage {
  shoTenborin(
    label: 'レベル1',
    threshold: 0,
    description: '金は「貯めるもの」→「流すもの」',
  ),
  engi(
    label: 'レベル2',
    threshold: 50,
    description: '使った金は消えず、誰かの元へ「縁」として巡る',
  ),
  kuu(
    label: 'レベルMAX',
    threshold: 100,
    description: '「自分の金」という観念自体が幻（マーヤー）',
  );

  const LevelStage({
    required this.label,
    required this.threshold,
    required this.description,
  });

  /// 段階の表示名
  final String label;

  /// この段階に到達するのに必要なEXP最小値
  final int threshold;

  /// 開眼する「気づき」の説明
  final String description;

  /// EXP値から適切な開眼段階を取得する
  static LevelStage fromExp(int exp) {
    if (exp >= LevelStage.kuu.threshold) {
      return LevelStage.kuu;
    } else if (exp >= LevelStage.engi.threshold) {
      return LevelStage.engi;
    }
    return LevelStage.shoTenborin;
  }
}

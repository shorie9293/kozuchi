/// 開眼の三段階
///
/// SATORI（悟り）値に応じてプレイヤーの開眼段階が変化する。
enum EnlightenmentStage {
  shoTenborin(
    label: '初転法輪',
    threshold: 0,
    description: '金は「貯めるもの」→「流すもの」',
  ),
  engi(
    label: '縁起',
    threshold: 50,
    description: '使った金は消えず、誰かの元へ「縁」として巡る',
  ),
  kuu(
    label: '空',
    threshold: 100,
    description: '「自分の金」という観念自体が幻（マーヤー）',
  );

  const EnlightenmentStage({
    required this.label,
    required this.threshold,
    required this.description,
  });

  /// 段階の表示名
  final String label;

  /// この段階に到達するのに必要なSATORI最小値
  final int threshold;

  /// 開眼する「気づき」の説明
  final String description;

  /// SATORI値から適切な開眼段階を取得する
  static EnlightenmentStage fromSatori(int satori) {
    if (satori >= EnlightenmentStage.kuu.threshold) {
      return EnlightenmentStage.kuu;
    } else if (satori >= EnlightenmentStage.engi.threshold) {
      return EnlightenmentStage.engi;
    }
    return EnlightenmentStage.shoTenborin;
  }
}

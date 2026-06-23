/// SATORI値の変動方向
enum SatoriDirection {
  /// 増加（悟りの深化）
  increase,

  /// 減少（悟りの後退・執着の再燃）
  decrease,
}

/// SATORI変動イベント
///
/// [SatoriChangeDetector] によって生成され、[SatoriEventDispatcher] を通じて
/// リスナーに同期的に配信される。
///
/// UI描画とは分離されたドメイン層のイベントであり、
/// アニメーションや表示更新のトリガーとして消費される。
class SatoriChangeEvent {
  /// 変動方向
  final SatoriDirection direction;

  /// 変動理由（日本語文字列）
  final String reason;

  /// 変動前のSATORI値
  final int oldValue;

  /// 変動後のSATORI値
  final int newValue;

  /// 変動量（絶対値）
  final int delta;

  /// 追加コンテキスト（アドバイザー名など）
  final String? context;

  const SatoriChangeEvent({
    required this.direction,
    required this.reason,
    required this.oldValue,
    required this.newValue,
    required this.delta,
    this.context,
  });

  @override
  String toString() {
    final arrow = direction == SatoriDirection.increase ? '↑' : '↓';
    return 'SatoriChangeEvent($arrow +$delta: "$reason", $oldValue → $newValue)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SatoriChangeEvent &&
        other.direction == direction &&
        other.reason == reason &&
        other.oldValue == oldValue &&
        other.newValue == newValue &&
        other.delta == delta &&
        other.context == context;
  }

  @override
  int get hashCode => Object.hash(direction, reason, oldValue, newValue, delta, context);
}

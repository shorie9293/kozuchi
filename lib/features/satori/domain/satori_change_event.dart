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

  /// 守護神の称賛メッセージ（支出記録直後に表示）
  final String? guardianPraise;

  /// 連続記録時のコンボ数（0=コンボなし）
  final int comboCount;

  const SatoriChangeEvent({
    required this.direction,
    required this.reason,
    required this.oldValue,
    required this.newValue,
    required this.delta,
    this.context,
    this.guardianPraise,
    this.comboCount = 0,
  });

  @override
  String toString() {
    final arrow = direction == SatoriDirection.increase ? '↑' : '↓';
    final combo = comboCount > 1 ? ' [${comboCount}連続]' : '';
    return 'SatoriChangeEvent($arrow +$delta: "$reason"$combo, $oldValue → $newValue)';
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
        other.context == context &&
        other.guardianPraise == guardianPraise &&
        other.comboCount == comboCount;
  }

  @override
  int get hashCode => Object.hash(
        direction,
        reason,
        oldValue,
        newValue,
        delta,
        context,
        guardianPraise,
        comboCount,
      );
}

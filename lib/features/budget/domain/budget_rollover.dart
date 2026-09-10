/// 予算の月次繰り越し（rollover）
///
/// 前月に使い切らなかった予算を翌月へ繰り越し、当月の基本予算に加算する。
/// 逆に前月が超過していた場合は、その超過額を当月頭に警告する。
/// すべての値は円単位の整数。I/Oを持たない不変（immutable）モデル。

/// 予算繰り越しの計算結果
///
/// - [baseBudget]: 当月に設定された基本予算額
/// - [carryOver]: 前月の残額から繰り越された額（0以上）
/// - [overspend]: 前月の超過額（0以上・超過がない場合は0）
/// - [enabled]: 繰り越し機能が有効かどうか
/// - [cap]: 繰り越し上限額（nullは無制限）
class BudgetRollover {
  /// 当月の基本予算額（円）
  final int baseBudget;

  /// 前月からの繰越額（円、0以上）
  final int carryOver;

  /// 前月の超過額（円、0以上）
  final int overspend;

  /// 繰り越し機能が有効かどうか
  final bool enabled;

  /// 繰り越し上限額（円、nullは無制限）
  final int? cap;

  const BudgetRollover({
    required this.baseBudget,
    this.carryOver = 0,
    this.overspend = 0,
    this.enabled = false,
    this.cap,
  })  : assert(baseBudget >= 0, '基本予算は0以上である必要があります'),
        assert(carryOver >= 0, '繰越額は0以上である必要があります'),
        assert(overspend >= 0, '超過額は0以上である必要があります');

  /// 繰越を反映した実質予算額（円）
  int get effectiveBudget => baseBudget + carryOver;

  /// 繰越額が存在するか
  bool get hasCarryOver => carryOver > 0;

  /// 前月の超過が存在するか
  bool get hasOverspend => overspend > 0;

  /// 繰り越し内容が未設定（繰越0・超過0）か
  bool get isNeutral => carryOver == 0 && overspend == 0;

  /// 実質予算に対する支出の比率（0.0〜、上限超過で1.0以上）
  double ratioOf(int spent) => effectiveBudget > 0 ? spent / effectiveBudget : 0;

  /// JSONから復元
  factory BudgetRollover.fromJson(Map<String, dynamic> json) {
    return BudgetRollover(
      baseBudget: json['baseBudget'] as int? ?? 0,
      carryOver: json['carryOver'] as int? ?? 0,
      overspend: json['overspend'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? false,
      cap: json['cap'] as int?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'baseBudget': baseBudget,
      'carryOver': carryOver,
      'overspend': overspend,
      'enabled': enabled,
    };
    if (cap != null) map['cap'] = cap;
    return map;
  }

  @override
  String toString() => 'BudgetRollover(base: $baseBudget, carryOver: $carryOver, '
      'overspend: $overspend, enabled: $enabled, cap: $cap)';
}

/// 予算繰り越しの設定（永続化対象）
///
/// [enabled] が false の場合は繰越を行わない（超過警告のみ表示）。
/// [cap] が null の場合は繰越上限なし。
class RolloverSettings {
  /// 繰り越し機能が有効かどうか
  final bool enabled;

  /// 繰り越し上限額（円、nullは無制限）
  final int? cap;

  const RolloverSettings({this.enabled = false, this.cap})
      : assert(cap == null || cap >= 0, '繰越上限は0以上である必要があります');

  /// デフォルト設定（繰り越し無効・上限なし）
  static const RolloverSettings defaults = RolloverSettings();

  /// JSONから復元
  factory RolloverSettings.fromJson(Map<String, dynamic> json) {
    return RolloverSettings(
      enabled: json['enabled'] as bool? ?? false,
      cap: json['cap'] as int?,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'enabled': enabled};
    if (cap != null) map['cap'] = cap;
    return map;
  }

  /// 設定の一部を更新したコピーを返す
  RolloverSettings copyWith({bool? enabled, int? cap, bool clearCap = false}) {
    return RolloverSettings(
      enabled: enabled ?? this.enabled,
      cap: clearCap ? null : (cap ?? this.cap),
    );
  }

  @override
  String toString() => 'RolloverSettings(enabled: $enabled, cap: $cap)';
}

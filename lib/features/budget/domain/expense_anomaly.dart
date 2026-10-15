import 'package:kozuchi/domain/models/expense_entry.dart';

/// 支出異常の深刻度
enum AnomalyLevel {
  elevated,
  high,
}

/// AnomalyLevel の日本語ラベル
extension AnomalyLevelLabel on AnomalyLevel {
  String get label => switch (this) {
        AnomalyLevel.elevated => 'やや高い',
        AnomalyLevel.high => 'いつもより高い',
      };
}

/// 異常と判定された支出1件の詳細
class ExpenseAnomaly {
  /// 異常と判定された支出
  final ExpenseEntry entry;

  /// 正規化済みカテゴリ名
  final String category;

  /// 支出金額（円）
  final int amount;

  /// 同カテゴリの過去平均（自分を除く）
  final double average;

  /// amount / average
  final double ratio;

  /// 判定に使った過去サンプル数
  final int sampleCount;

  /// 深刻度
  final AnomalyLevel level;

  /// 不変条件を本体で強制する（const の assert は使わない）
  ExpenseAnomaly({
    required this.entry,
    required this.category,
    required this.amount,
    required this.average,
    required this.ratio,
    required this.sampleCount,
    required this.level,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'amount must be positive');
    }
    if (average <= 0) {
      throw ArgumentError.value(average, 'average', 'average must be positive');
    }
    if (ratio < 1.0) {
      throw ArgumentError.value(ratio, 'ratio', 'ratio must be >= 1.0');
    }
  }

  /// 常に固定メッセージ
  String get message => 'いつもより高い支出です';

  /// 例: 「いつもの 2.4倍」（小数第1位）
  String get ratioLabel {
    final rounded = (ratio * 10).roundToDouble() / 10;
    return 'いつもの ${rounded.toStringAsFixed(1)}倍';
  }
}
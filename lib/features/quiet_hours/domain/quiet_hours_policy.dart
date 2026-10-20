/// 静穏時間（おやすみモード）中に通知が来た場合の方針。
enum QuietHoursPolicy {
  /// 翌朝まで繰り延べる。
  defer(label: '翌朝に繰り延べ', storageKey: 'defer'),

  /// その通知を出さない。
  skip(label: '通知しない', storageKey: 'skip');

  const QuietHoursPolicy({required this.label, required this.storageKey});

  /// 表示名。
  final String label;

  /// 永続化用キー。
  final String storageKey;

  /// storageKey から復元する（未知・空は [defer]）。
  static QuietHoursPolicy fromStorageKey(String key) {
    for (final policy in QuietHoursPolicy.values) {
      if (policy.storageKey == key) return policy;
    }
    return QuietHoursPolicy.defer;
  }
}

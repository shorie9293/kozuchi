/// バックアップバンドルのスキーマバージョン。
///
/// 復元時の互換性判定に用いる（破壊的変更時のみ増やす）。
const int kBackupSchemaVersion = 1;

/// プレフィックス一致でバックアップ対象とする SharedPreferences キー群。
const List<String> kBackupKeyPrefixes = [
  'kozuchi_',
  'kozuchi',
  'rpg_bonus_daily_count_',
];

/// 完全一致でバックアップ対象とする SharedPreferences キー群。
const List<String> kBackupKeyExact = [
  'player_save',
  'player_saves',
  'budget_alert',
  'budget_perfect_days',
  'budget_set_count',
  'daily_quests',
  'daily_reminder',
  'goals',
  'recurring_transaction',
  'streak_days',
  'tags',
  'notification_enabled',
  'notification_hour',
  'notification_minute',
  'rpg_bonus_log',
  'income_entries',
  'notification_settings_v1',
];

/// エクスポート／バックアップの対象データ一式（Key-Value スナップショット）。
///
/// SharedPreferences のキー値とその値をまとめて持ち、
/// JSON への直列化／復元を担う。
class BackupBundle {
  final int schemaVersion;
  final DateTime exportedAt;
  final Map<String, Object?> entries;

  /// [schemaVersion] が1未満は不正（[ArgumentError]）。
  BackupBundle({
    this.schemaVersion = kBackupSchemaVersion,
    required this.exportedAt,
    required this.entries,
  }) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'must be >= 1',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'entries': entries,
      };

  /// JSON マップから復元する。
  ///
  /// 必須項目の欠落・型不一致・不正な日付は [FormatException]。
  factory BackupBundle.fromJson(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    if (schemaVersion is! int) {
      throw const FormatException('BackupBundle.schemaVersion is missing');
    }
    final exportedAtRaw = map['exportedAt'];
    if (exportedAtRaw is! String) {
      throw const FormatException('BackupBundle.exportedAt is missing');
    }
    final exportedAt = DateTime.tryParse(exportedAtRaw);
    if (exportedAt == null) {
      throw const FormatException('BackupBundle.exportedAt is invalid');
    }
    final entriesRaw = map['entries'];
    if (entriesRaw is! Map<String, dynamic>) {
      throw const FormatException('BackupBundle.entries is missing');
    }
    final entries = <String, Object?>{};
    entriesRaw.forEach((key, value) {
      if (!_isValidEntryValue(value)) {
        throw FormatException('BackupBundle.entries[$key] is invalid');
      }
      entries[key] = value;
    });
    return BackupBundle(
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      entries: entries,
    );
  }

  /// スナップショット値として許容される型か（String/int/double/bool/List<String>）。
  static bool _isValidEntryValue(Object? value) {
    if (value is String || value is int || value is double || value is bool) {
      return true;
    }
    if (value is List) {
      return value.every((item) => item is String);
    }
    return false;
  }

  /// バックアップ対象キーの登録件数。
  int get entryCount => entries.length;

  /// 対象キーが1件も無いかどうか。
  bool get isEmpty => entries.isEmpty;
}

/// リストア（復元）結果の件数集計。
class RestoreResult {
  final int created;
  final int restored;
  final int unchanged;

  const RestoreResult({
    required this.created,
    required this.restored,
    required this.unchanged,
  });

  int get total => created + restored + unchanged;

  /// 例: 「新規 3件 / 更新 2件 / 変更なし 1件」
  String get label =>
      '新規 ${created}件 / 更新 ${restored}件 / 変更なし ${unchanged}件';
}

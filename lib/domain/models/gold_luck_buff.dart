import 'dart:convert';

/// 金運上昇バフ（つんどく読了ボーナス）
///
/// tsundoku-questで本を読了すると発動する一時的なバフ。
/// 効果時間中は収入（addHp）に倍率がかかる。
///
/// スタッキング: 非スタッキング（新規発動で持続時間をリセット、倍率は上書きしない）
class GoldLuckBuff {
  /// 金運倍率（例: 2.0 = 収入2倍）
  final double multiplier;

  /// バフの有効期限（UTC）
  final DateTime expiresAt;

  /// バフの発生源（book_completed / other）
  final String source;

  /// 読了した本のタイトル（UI表示用、任意）
  final String? bookTitle;

  /// 発動時刻（UTC）
  final DateTime activatedAt;

  const GoldLuckBuff({
    required this.multiplier,
    required this.expiresAt,
    required this.source,
    this.bookTitle,
    required this.activatedAt,
  });

  /// バフが現在有効か
  bool get isActive => DateTime.now().toUtc().isBefore(expiresAt);

  /// バフの残り時間（有効でなければnull）
  Duration? get remaining {
    if (!isActive) return null;
    return expiresAt.difference(DateTime.now().toUtc());
  }

  /// 残り時間を人間可読な文字列で返す
  String get remainingDisplay {
    final r = remaining;
    if (r == null) return '期限切れ';
    final minutes = r.inMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '残り${hours}時間${mins > 0 ? '${mins}分' : ''}';
    }
    return '残り${minutes}分';
  }

  /// デフォルトのバフを生成（読了イベント用）
  ///
  /// [bookTitle] 読了した本のタイトル（任意）
  factory GoldLuckBuff.forBookCompleted({
    String? bookTitle,
    double multiplier = 2.0,
    Duration duration = const Duration(minutes: 60),
  }) {
    final now = DateTime.now().toUtc();
    return GoldLuckBuff(
      multiplier: multiplier,
      expiresAt: now.add(duration),
      source: 'book_completed',
      bookTitle: bookTitle,
      activatedAt: now,
    );
  }

  /// JSONから復元
  factory GoldLuckBuff.fromJson(Map<String, dynamic> json) {
    return GoldLuckBuff(
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 2.0,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      source: json['source'] as String? ?? 'book_completed',
      bookTitle: json['bookTitle'] as String?,
      activatedAt: DateTime.parse(json['activatedAt'] as String),
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'multiplier': multiplier,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'source': source,
      'bookTitle': bookTitle,
      'activatedAt': activatedAt.toUtc().toIso8601String(),
    };
  }

  /// JSON文字列から復元
  factory GoldLuckBuff.fromJsonString(String jsonString) {
    return GoldLuckBuff.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// JSON文字列に変換
  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() =>
      'GoldLuckBuff(multiplier: ${multiplier}x, remaining: $remainingDisplay, source: $source)';
}

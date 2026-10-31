import 'dart:convert';

/// 端末内クラッシュログの発生源。
enum CrashKind {
  /// Flutter フレームワーク内の例外（FlutterError.onError）
  flutterError('flutter'),

  /// runZonedGuarded で拾ったゾーン外／非同期の例外
  zoneError('zone'),

  /// PlatformDispatcher.onError に届いたプラットフォーム例外
  platformError('platform');

  const CrashKind(this.id);

  /// JSON へ書き出す識別子。
  final String id;

  /// 未知の識別子は [CrashKind.zoneError] として扱う（前方互換）。
  static CrashKind fromId(Object? id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return CrashKind.zoneError;
  }

  /// 一覧表示用の短いラベル。
  String get label => switch (this) {
        CrashKind.flutterError => '画面描画',
        CrashKind.zoneError => '非同期',
        CrashKind.platformError => '基盤',
      };
}

/// 端末内に残す1件のクラッシュ記録（純粋モデル）。
///
/// - 個人情報が混ざりやすい長文を避けるため、[message] は先頭
///   [maxMessageChars] 文字、[stackTop] は先頭 [maxStackFrames] フレームに制限する。
/// - JSON からの復元に失敗した場合は null を返す（壊れた行は黙って読み飛ばす）。
class CrashLogEntry {
  const CrashLogEntry({
    required this.timestamp,
    required this.kind,
    required this.message,
    required this.stackTop,
  });

  /// message の保持上限（文字数）。
  static const int maxMessageChars = 200;

  /// stackTop の保持上限（フレーム数）。
  static const int maxStackFrames = 10;

  final DateTime timestamp;
  final CrashKind kind;
  final String message;
  final String stackTop;

  /// 例外から記録を作る。長大な文字列はここで切り詰める。
  factory CrashLogEntry.fromError(
    Object error,
    StackTrace? stack, {
    required CrashKind kind,
    DateTime? timestamp,
  }) {
    return CrashLogEntry(
      timestamp: timestamp ?? DateTime.now(),
      kind: kind,
      message: truncateMessage(error.toString()),
      stackTop: truncateStack(stack?.toString()),
    );
  }

  /// 空白を1つに畳んでから先頭 [maxMessageChars] 文字に切り詰める。
  static String truncateMessage(String raw) {
    final flattened = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flattened.length <= maxMessageChars) return flattened;
    return flattened.substring(0, maxMessageChars);
  }

  /// スタックトレースの先頭 [maxStackFrames] 行のみを保持する。
  static String truncateStack(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final lines = raw.split('\n').where((line) => line.trim().isNotEmpty).take(
          maxStackFrames,
        );
    return lines.join('\n');
  }

  /// 一覧表示用の時刻表記（HH:mm）。
  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ts': timestamp.toIso8601String(),
        'kind': kind.id,
        'message': message,
        'stack': stackTop,
      };

  /// JSON からの復元。壊れていれば null（呼び出し側は行ごと読み飛ばす）。
  static CrashLogEntry? fromJson(Map<String, dynamic> json) {
    final rawTs = json['ts'];
    if (rawTs is! String) return null;
    final ts = DateTime.tryParse(rawTs);
    if (ts == null) return null;

    final rawMessage = json['message'];
    if (rawMessage is! String || rawMessage.isEmpty) return null;

    final rawStack = json['stack'];
    return CrashLogEntry(
      timestamp: ts,
      kind: CrashKind.fromId(json['kind']),
      message: rawMessage,
      stackTop: rawStack is String ? rawStack : '',
    );
  }

  /// 1行の JSON 文字列からの復元。壊れた行は null。
  static CrashLogEntry? tryDecodeLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return null;
      return fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  String encodeLine() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrashLogEntry &&
          other.timestamp == timestamp &&
          other.kind == kind &&
          other.message == message &&
          other.stackTop == stackTop;

  @override
  int get hashCode => Object.hash(timestamp, kind, message, stackTop);

  @override
  String toString() => 'CrashLogEntry(${kind.id}, $timestamp, $message)';
}

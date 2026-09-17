/// レシート原本画像への参照（不変モデル）。
///
/// パスの正規化（trim）とファイル名・拡張子の導出を担う。
/// 純粋な値オブジェクトであり、I/O は行わない。
class ReceiptImageRef {
  /// 正規化済み（trim 済み）画像パス。
  final String path;

  /// 不変条件: path は trim 後非空。
  ///
  /// kozuchi 掟: const コンストラクタの assert では強制できないため、
  /// 非const コンストラクタ本体で ArgumentError を throw する。
  ReceiptImageRef({required String path}) : path = path.trim() {
    if (this.path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'レシート画像パスは空にできない');
    }
  }

  /// null / trim 後空 なら null、それ以外は trim した [ReceiptImageRef]。
  static ReceiptImageRef? tryFromPath(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return ReceiptImageRef(path: trimmed);
  }

  /// パス区切り（`/` と `\`）で分けた最終要素。空なら path 自身。
  String get fileName {
    final parts = path.split(RegExp(r'[/\\]'));
    final last = parts.last;
    return last.isEmpty ? path : last;
  }

  /// 拡張子（小文字）。ドット無しは空文字。
  String get extension {
    final name = fileName;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) {
      return '';
    }
    return name.substring(dot + 1).toLowerCase();
  }

  /// 対応形式（jpg/jpeg/png/webp/heic/heif）かどうか。
  bool get isSupportedImage {
    const supported = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    return supported.contains(extension);
  }

  /// 表示用ラベル。fileName を返す。空なら 'レシート画像'。
  String get label {
    final name = fileName;
    return name.isEmpty ? 'レシート画像' : name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptImageRef && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'ReceiptImageRef(path: $path)';
}

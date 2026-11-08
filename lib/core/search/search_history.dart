import 'dart:convert';

/// 検索語の履歴（新しい順・最大 [maxEntries] 件）を保持する不変モデル。
///
/// 正規化規則:
/// - 前後の空白（半角・全角）を除去
/// - 全角空白（U+3000）は半角空白へ変換
/// - 連続する空白は 1 個へ畳み込み
/// - 正規化後に空文字なら追加しない
/// - 大小文字を無視して重複する語は「先頭へ移動＋表記を最新で上書き」
///
/// 永続化は [encode] / [decode] の JSON 文字列で行う。
/// [decode] は決して例外を投げず、破損時は空の履歴を返す。
class SearchHistory {
  SearchHistory._(this._entries);

  /// 保持できる最大件数。
  static const int maxEntries = 8;

  final List<String> _entries;

  /// 空の履歴。
  factory SearchHistory.empty() => SearchHistory._(const <String>[]);

  /// 任意の並び（新しい順を想定）から履歴を作る。
  ///
  /// 正規化・大小文字無視の重複排除（最初の出現を優先）・上限 [maxEntries] を適用する。
  factory SearchHistory.fromIterable(Iterable<String> terms) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in terms) {
      final term = _normalize(raw);
      if (term.isEmpty) continue;
      final key = _foldCase(term);
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(term);
      if (result.length >= maxEntries) break;
    }
    return SearchHistory._(List<String>.unmodifiable(result));
  }

  /// 新しい順の検索語一覧（変更不可）。
  List<String> get entries => _entries;

  /// 履歴が空かどうか。
  bool get isEmpty => _entries.isEmpty;

  /// 履歴が空でないかどうか。
  bool get isNotEmpty => _entries.isNotEmpty;

  /// 件数。
  int get length => _entries.length;

  /// 検索語を追加した新しい履歴を返す。
  ///
  /// 空（正規化後）なら自分自身を返す。既存の同一語（大小文字無視）は
  /// 先頭へ移動し、表記は今回の入力で上書きする。上限を超えた最古の語は捨てる。
  SearchHistory add(String raw) {
    final term = _normalize(raw);
    if (term.isEmpty) return this;

    final key = _foldCase(term);
    final next = <String>[term];
    for (final existing in _entries) {
      if (_foldCase(existing) == key) continue;
      next.add(existing);
      if (next.length >= maxEntries) break;
    }
    return SearchHistory._(List<String>.unmodifiable(next));
  }

  /// JSON 文字列へ変換する。
  String encode() => jsonEncode(_entries);

  /// JSON 文字列から復元する。破損・型不一致・null は空の履歴になる（例外は投げない）。
  factory SearchHistory.decode(String? raw) {
    if (raw == null || raw.isEmpty) return SearchHistory.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return SearchHistory.empty();
      return SearchHistory.fromIterable(decoded.whereType<String>());
    } catch (_) {
      return SearchHistory.empty();
    }
  }

  static String _foldCase(String value) => value.toLowerCase();

  static String _normalize(String raw) {
    final halfWidth = raw.replaceAll('\u3000', ' ');
    return halfWidth.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchHistory) return false;
    if (other._entries.length != _entries.length) return false;
    for (var i = 0; i < _entries.length; i++) {
      if (other._entries[i] != _entries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_entries);

  @override
  String toString() => 'SearchHistory($_entries)';
}
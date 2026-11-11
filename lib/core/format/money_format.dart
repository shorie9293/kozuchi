/// 金額の表示文字列を組み立てる正準モジュール。
///
/// 金額整形の流儀（丸め規則・記号の位置）を呼出側に選ばせないため、
/// 用途ごとに固定した4関数のみを公開する。フラグ引数は持たない。
///
/// 契約:
/// - 純粋関数のみ。外部依存なし。
/// - いかなる入力でも例外を投げない（[int] の全範囲で文字列を返す）。
/// - 負値は `-¥1,000` の形。記号の後ろにマイナスを付けない。
/// - 0 はつねに `¥0` / `0`。`-¥0` は生成しない。
library;

/// 3桁区切りの桁数。
const int _groupSize = 3;

/// 符号接頭辞の表。索引は `amount.compareTo(0) + 1`（負・零・正）。
///
/// 零と正は接頭辞なし。これにより `-¥0` が構造的に発生しない。
/// 正値の `+` は [formatYenSigned] だけが付す。
const List<String> _signTable = <String>['-', '', ''];

/// 3桁ごとにカンマを挿入する共通ヘルパ。`digits` は符号なしの数字列。
///
/// 空文字を渡されても例外にせず `0` を返す。
String _groupDigits(String digits) {
  if (digits.isEmpty) return '0';
  final buffer = StringBuffer();
  final lead = digits.length % _groupSize;
  if (lead != 0) {
    buffer.write(digits.substring(0, lead));
  }
  for (var i = lead; i < digits.length; i += _groupSize) {
    if (buffer.isNotEmpty) buffer.write(',');
    buffer.write(digits.substring(i, i + _groupSize));
  }
  return buffer.toString();
}

/// 符号・記号・3桁区切りを組み立てる唯一の実装。
///
/// [symbol] は通貨記号（空文字可）、[suffix] は単位（`万` 等）。
/// 絶対値は `toString()` の先頭1文字を落として作るため、
/// `abs()` が自身を返す最小値でも破綻しない。
String _compose(int amount, {String symbol = '', String suffix = ''}) {
  final sign = _signTable[amount.compareTo(0) + 1];
  final digits = amount.toString();
  final body = digits.startsWith('-') ? digits.substring(1) : digits;
  return '$sign$symbol${_groupDigits(body)}$suffix';
}

/// 3桁カンマ＋`¥` 記号の金額表記を返す。
///
/// 例: `0` → `¥0`、`19999` → `¥19,999`、`-1500` → `-¥1,500`。
String formatYen(int amount) => _compose(amount, symbol: '¥');

/// 符号を明示する金額表記を返す。入出金の向きを示す画面用。
///
/// 例: `1000` → `+¥1,000`、`-1000` → `-¥1,000`、`0` → `¥0`。
String formatYenSigned(int amount) {
  final base = formatYen(amount);
  return amount > 0 ? '+$base' : base;
}

/// 記号なしの3桁カンマ表記を返す。ラベル側に既に `¥` がある画面用。
///
/// 例: `1000` → `1,000`、`-1500` → `-1,500`、`0` → `0`。
String formatYenBare(int amount) => _compose(amount);

/// 万単位の略記を返す。丸めは**切り捨て**（`amount ~/ 10000`）で固定。
///
/// 四捨五入はしない（`19999` は `2.0万` ではなく `1万`）。
/// 絶対値が1万未満なら [formatYen] に委譲する。
///
/// 例: `19999` → `1万`、`10000` → `1万`、`9999` → `¥9,999`、`-19999` → `-1万`。
String formatYenCompact(int amount) {
  if (amount.abs() < 10000) {
    return formatYen(amount);
  }
  return _compose(amount ~/ 10000, suffix: '万');
}

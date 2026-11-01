import 'dart:convert';
import 'dart:typed_data';

/// UTF-8 BOM（U+FEFF）。
///
/// Excel は BOM 無しUTF-8 を ANSI（Shift_JIS系）と解釈して日本語を化けさせるため、
/// ファイルへ書き出す層でだけ BOM を付与する。
const String utf8Bom = '\uFEFF';

/// [csv] の先頭に UTF-8 BOM を付けた文字列を返す。
///
/// 純粋関数。CSV生成関数の戻り値は変えず、書き出し直前にこの関数を通す。
String withUtf8Bom(String csv) => '$utf8Bom$csv';

/// [csv] を BOM 付きUTF-8 のバイト列にする（先頭3バイトは 0xEF, 0xBB, 0xBF）。
///
/// `codeUnits` ではなく `utf8.encode` を使う（前者は日本語を1バイトに潰す）。
Uint8List csvBytes(String csv) => Uint8List.fromList(utf8.encode(withUtf8Bom(csv)));

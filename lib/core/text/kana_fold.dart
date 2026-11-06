/// かな表記ゆれの吸収（かな畳み込み）。
///
/// 検索・照合のために、ひらがな・半角カナを全角カタカナへ寄せる純粋関数。
/// 表示用の文字列整形には使わない（戻り値は表示に適さない）。
library;

/// 半角カナ（U+FF66–U+FF9F）→ 全角カタカナの表引き。
///
/// 濁点・半濁点（U+FF9E / U+FF9F）は単独では結合せず、
/// 直前の基底文字と組み合わせて濁音・半濁音へ合成する。
const Map<int, int> _halfwidthToFullwidth = <int, int>{
  0xFF66: 0x30F2, // ｦ → ヲ
  0xFF67: 0x30A1, // ｧ → ァ
  0xFF68: 0x30A3, // ｨ → ィ
  0xFF69: 0x30A5, // ｩ → ゥ
  0xFF6A: 0x30A7, // ｪ → ェ
  0xFF6B: 0x30A9, // ｫ → ォ
  0xFF6C: 0x30E3, // ｬ → ャ
  0xFF6D: 0x30E5, // ｭ → ュ
  0xFF6E: 0x30E7, // ｮ → ョ
  0xFF6F: 0x30C3, // ｯ → ッ
  0xFF70: 0x30FC, // ｰ → ー
  0xFF71: 0x30A2, // ｱ → ア
  0xFF72: 0x30A4, // ｲ → イ
  0xFF73: 0x30A6, // ｳ → ウ
  0xFF74: 0x30A8, // ｴ → エ
  0xFF75: 0x30AA, // ｵ → オ
  0xFF76: 0x30AB, // ｶ → カ
  0xFF77: 0x30AD, // ｷ → キ
  0xFF78: 0x30AF, // ｸ → ク
  0xFF79: 0x30B1, // ｹ → ケ
  0xFF7A: 0x30B3, // ｺ → コ
  0xFF7B: 0x30B5, // ｻ → サ
  0xFF7C: 0x30B7, // ｼ → シ
  0xFF7D: 0x30B9, // ｽ → ス
  0xFF7E: 0x30BB, // ｾ → セ
  0xFF7F: 0x30BD, // ｿ → ソ
  0xFF80: 0x30BF, // ﾀ → タ
  0xFF81: 0x30C1, // ﾁ → チ
  0xFF82: 0x30C4, // ﾂ → ツ
  0xFF83: 0x30C6, // ﾃ → テ
  0xFF84: 0x30C8, // ﾄ → ト
  0xFF85: 0x30CA, // ﾅ → ナ
  0xFF86: 0x30CB, // ﾆ → ニ
  0xFF87: 0x30CC, // ﾇ → ヌ
  0xFF88: 0x30CD, // ﾈ → ネ
  0xFF89: 0x30CE, // ﾉ → ノ
  0xFF8A: 0x30CF, // ﾊ → ハ
  0xFF8B: 0x30D2, // ﾋ → ヒ
  0xFF8C: 0x30D5, // ﾌ → フ
  0xFF8D: 0x30D8, // ﾍ → ヘ
  0xFF8E: 0x30DB, // ﾎ → ホ
  0xFF8F: 0x30DE, // ﾏ → マ
  0xFF90: 0x30DF, // ﾐ → ミ
  0xFF91: 0x30E0, // ﾑ → ム
  0xFF92: 0x30E1, // ﾒ → メ
  0xFF93: 0x30E2, // ﾓ → モ
  0xFF94: 0x30E4, // ﾔ → ヤ
  0xFF95: 0x30E6, // ﾕ → ユ
  0xFF96: 0x30E8, // ﾖ → ヨ
  0xFF97: 0x30E9, // ﾗ → ラ
  0xFF98: 0x30EA, // ﾘ → リ
  0xFF99: 0x30EB, // ﾙ → ル
  0xFF9A: 0x30EC, // ﾚ → レ
  0xFF9B: 0x30ED, // ﾛ → ロ
  0xFF9C: 0x30EF, // ﾜ → ワ
  0xFF9D: 0x30F3, // ﾝ → ン
};

/// 全角カタカナ（濁音化前）→ 濁音。
const Map<int, int> _voiced = <int, int>{
  0x30A6: 0x30F4, // ウ → ヴ
  0x30A4: 0x30F8, // イ → ヸ
  0x30A8: 0x30F9, // エ → ヹ
  0x30AA: 0x30FA, // オ → ヺ
  0x30EF: 0x30F7, // ワ → ヷ
  0x30AB: 0x30AC, // カ → ガ
  0x30AD: 0x30AE, // キ → ギ
  0x30AF: 0x30B0, // ク → グ
  0x30B1: 0x30B2, // ケ → ゲ
  0x30B3: 0x30B4, // コ → ゴ
  0x30B5: 0x30B6, // サ → ザ
  0x30B7: 0x30B8, // シ → ジ
  0x30B9: 0x30BA, // ス → ズ
  0x30BB: 0x30BC, // セ → ゼ
  0x30BD: 0x30BE, // ソ → ゾ
  0x30BF: 0x30C0, // タ → ダ
  0x30C1: 0x30C2, // チ → ヂ
  0x30C4: 0x30C5, // ツ → ヅ
  0x30C6: 0x30C7, // テ → デ
  0x30C8: 0x30C9, // ト → ド
  0x30CF: 0x30D0, // ハ → バ
  0x30D2: 0x30D3, // ヒ → ビ
  0x30D5: 0x30D6, // フ → ブ
  0x30D8: 0x30D9, // ヘ → ベ
  0x30DB: 0x30DC, // ホ → ボ
};

/// 全角カタカナ（半濁音化前）→ 半濁音。
const Map<int, int> _semiVoiced = <int, int>{
  0x30CF: 0x30D1, // ハ → パ
  0x30D2: 0x30D4, // ヒ → ピ
  0x30D5: 0x30D7, // フ → プ
  0x30D8: 0x30DA, // ヘ → ペ
  0x30DB: 0x30DD, // ホ → ポ
};

const int _halfwidthVoicedMark = 0xFF9E; // ﾞ
const int _halfwidthSemiVoicedMark = 0xFF9F; // ﾟ

/// ひらがな・半角カナを全角カタカナへ畳み込む。
///
/// - ひらがな U+3041–U+3096 → カタカナ（+0x60）。ゕ/ゖ も ヵ/ヶ になる
/// - 半角カナ U+FF66–U+FF9D → 全角カタカナ（表引き）
/// - 半角カナ + ﾞ/ﾟ → 濁音・半濁音（ｶﾞ→ガ、ﾊﾟ→パ、ｳﾞ→ヴ 等）
/// - 全角カタカナ・ASCII・漢字は不変
/// - 冪等（foldKana(foldKana(x)) == foldKana(x)）
String foldKana(String input) {
  if (input.isEmpty) return input;
  final runes = input.runes.toList(growable: false);
  final buffer = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    final code = runes[i];

    // ひらがな → カタカナ
    if (code >= 0x3041 && code <= 0x3096) {
      buffer.writeCharCode(code + 0x60);
      continue;
    }

    // 半角カナ → 全角カタカナ（濁点・半濁点は合成）
    final fullwidth = _halfwidthToFullwidth[code];
    if (fullwidth != null) {
      if (i + 1 < runes.length) {
        final next = runes[i + 1];
        if (next == _halfwidthVoicedMark) {
          final combined = _voiced[fullwidth];
          if (combined != null) {
            buffer.writeCharCode(combined);
            i++;
            continue;
          }
        } else if (next == _halfwidthSemiVoicedMark) {
          final combined = _semiVoiced[fullwidth];
          if (combined != null) {
            buffer.writeCharCode(combined);
            i++;
            continue;
          }
        }
      }
      buffer.writeCharCode(fullwidth);
      continue;
    }

    // 単独の濁点・半濁点は全角の記号へ（結合先が無い場合）
    if (code == _halfwidthVoicedMark) {
      buffer.writeCharCode(0x309B); // ゛
      continue;
    }
    if (code == _halfwidthSemiVoicedMark) {
      buffer.writeCharCode(0x309C); // ゜
      continue;
    }

    buffer.writeCharCode(code);
  }
  return buffer.toString();
}

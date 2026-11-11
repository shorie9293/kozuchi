/// 金額文字列の正規化とパースを行う純粋クラス。
///
/// 日本語IMEが生成する全角数字・全角カンマ・全角マイナスを吸収し、
/// 例外を投げずに結果型で理由を返す。UI層は日本語の理由文言をここから取る。
library;

/// 金額パースの結果。
///
/// [value] が非 null なら正当、null なら [errorMessage] に理由が入る。
class AmountParseResult {
  /// パース成功時の金額。失敗時は null。
  final int? value;

  /// パース失敗時の日本語理由。成功時は null。
  final String? errorMessage;

  const AmountParseResult._(this.value, this.errorMessage);

  /// 正当な金額として解釈できたか。
  bool get isValid => value != null;
}

/// 金額文字列の正規化・パースを担う純粋クラス。
///
/// サービスは throw しない契約に従い、[tryParse] / [parseAmount] は
/// いかなる入力でも例外を投げない。
class AmountParser {
  const AmountParser._();

  /// 空入力の理由文言。
  static const String emptyMessage = '金額を入力してください';

  /// 非数の理由文言。
  static const String notNumberMessage = '金額は数字で入力してください';

  /// 0 が許されない場合の理由文言。
  static const String zeroNotAllowedMessage = '金額は1円以上を入力してください';

  /// 負値が許されない場合の理由文言。
  static const String negativeNotAllowedMessage = '金額はマイナスにできません';

  /// 全角数字・カンマ・全角空白・全角マイナスを正規化する。
  ///
  /// 戻り値はパース用の文字列であり、表示用ではない。
  static String normalize(String raw) {
    final normalized = raw
        .replaceAll('　', ' ')
        .replaceAllMapped(
          RegExp(r'[０-９]'),
          (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0),
        )
        .replaceAll('，', '')
        .replaceAll(',', '')
        .replaceAll('－', '-')
        .replaceAll('\u2212', '-');
    return normalized.trim();
  }

  /// 金額文字列をパースする。例外は投げない。
  ///
  /// 空・非数は null。[allowZero] が false なら 0 は null、
  /// [allowNegative] が false なら負値は null。
  static int? tryParse(
    String raw, {
    bool allowZero = false,
    bool allowNegative = false,
  }) {
    final value = int.tryParse(normalize(raw));
    if (value == null) return null;
    if (value == 0) return allowZero ? 0 : null;
    if (value < 0 && !allowNegative) return null;
    return value;
  }

  /// 金額文字列をパースし、失敗理由つきの結果を返す。例外は投げない。
  static AmountParseResult parseAmount(
    String raw, {
    bool allowZero = false,
    bool allowNegative = false,
  }) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) {
      return const AmountParseResult._(null, emptyMessage);
    }
    final value = int.tryParse(normalized);
    if (value == null) {
      return const AmountParseResult._(null, notNumberMessage);
    }
    if (value == 0 && !allowZero) {
      return const AmountParseResult._(null, zeroNotAllowedMessage);
    }
    if (value < 0 && !allowNegative) {
      return const AmountParseResult._(null, negativeNotAllowedMessage);
    }
    return AmountParseResult._(value, null);
  }
}

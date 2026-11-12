import 'dart:convert';

import 'package:kozuchi/features/recurring_transaction/domain/recurring_transaction.dart';

/// 定期取引の保存データを読んだ結果（純粋層）。
///
/// 「保存が無い（正常な空）」と「読めなかった（破損）」を区別する。
/// 区別しないまま空リストを信じると、次の1件追加で既存定義を丸ごと
/// 上書きして恒久破壊する（本型はその事故を構造で防ぐための土台）。
class RecurringDefinitionsLoadResult {
  /// 復元できた定義（破損時は読めた分だけ）
  final List<RecurringTransaction> definitions;

  /// 保存データを信頼できるか。false の間は上書き保存を禁ずる。
  final bool verified;

  /// 利用者に見せる理由（verified=true なら null）
  final String? errorMessage;

  /// 読み飛ばした要素数
  final int skippedCount;

  RecurringDefinitionsLoadResult({
    List<RecurringTransaction> definitions = const [],
    required this.verified,
    this.errorMessage,
    this.skippedCount = 0,
  }) : definitions = List<RecurringTransaction>.unmodifiable(definitions);

  /// 未保存（＝正常な空）
  static final RecurringDefinitionsLoadResult empty =
      RecurringDefinitionsLoadResult(verified: true);

  static const String corruptMessage = '定期取引の保存データが壊れています';
  static const String wrongShapeMessage = '定期取引の保存データの形式が不正です';

  bool get isCorrupt => !verified;
  bool get isEmpty => definitions.isEmpty;

  /// 生の保存文字列を解釈する。**絶対に throw しない。**
  factory RecurringDefinitionsLoadResult.parse(String? raw) {
    if (raw == null) return empty;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return RecurringDefinitionsLoadResult(
        verified: false,
        errorMessage: corruptMessage,
      );
    }

    if (decoded is! List) {
      return RecurringDefinitionsLoadResult(
        verified: false,
        errorMessage: wrongShapeMessage,
      );
    }

    final parsed = <RecurringTransaction>[];
    var skipped = 0;
    for (final element in decoded) {
      try {
        if (element is! Map) {
          skipped++;
          continue;
        }
        parsed.add(
          RecurringTransaction.fromJson(Map<String, dynamic>.from(element)),
        );
      } catch (_) {
        skipped++;
      }
    }

    if (skipped == 0) {
      return RecurringDefinitionsLoadResult(
        definitions: parsed,
        verified: true,
      );
    }
    return RecurringDefinitionsLoadResult(
      definitions: parsed,
      verified: false,
      errorMessage: corruptMessage,
      skippedCount: skipped,
    );
  }
}

/// 定期取引の保存結果。
class RecurringSaveResult {
  final bool ok;
  final String? errorMessage;

  const RecurringSaveResult({required this.ok, this.errorMessage});

  static const RecurringSaveResult success = RecurringSaveResult(ok: true);

  static const String blockedMessage =
      '破損した保存データを上書きしないため、保存を中止しました。'
      '「破損データを退避して新規作成」を実行してください';

  factory RecurringSaveResult.blocked([String? reason]) {
    return RecurringSaveResult(ok: false, errorMessage: reason ?? blockedMessage);
  }
}

/// 定期取引の最終生成日時を読んだ結果（純粋層）。
///
/// 破損した Map を空として信じると、保存時に**他の全定義の進捗が消え**、
/// 次回起動で期間全体が再生成されて取引が二重計上される。
class RecurringLastGeneratedResult {
  final Map<String, DateTime> values;
  final bool verified;
  final String? errorMessage;
  final int skippedCount;

  RecurringLastGeneratedResult({
    Map<String, DateTime> values = const {},
    required this.verified,
    this.errorMessage,
    this.skippedCount = 0,
  }) : values = Map<String, DateTime>.unmodifiable(values);

  static final RecurringLastGeneratedResult empty =
      RecurringLastGeneratedResult(verified: true);

  static const String corruptMessage = '定期取引の生成進捗データが壊れています';

  bool get isCorrupt => !verified;

  DateTime? valueFor(String id) => values[id];

  /// 生の保存文字列を解釈する。**絶対に throw しない。**
  factory RecurringLastGeneratedResult.parse(String? raw) {
    if (raw == null) return empty;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return RecurringLastGeneratedResult(
        verified: false,
        errorMessage: corruptMessage,
      );
    }

    if (decoded is! Map) {
      return RecurringLastGeneratedResult(
        verified: false,
        errorMessage: corruptMessage,
      );
    }

    final values = <String, DateTime>{};
    var skipped = 0;
    decoded.forEach((key, value) {
      if (key is! String || value is! String) {
        skipped++;
        return;
      }
      final parsed = DateTime.tryParse(value);
      if (parsed == null) {
        skipped++;
        return;
      }
      values[key] = parsed;
    });

    if (skipped == 0) {
      return RecurringLastGeneratedResult(values: values, verified: true);
    }
    return RecurringLastGeneratedResult(
      values: values,
      verified: false,
      errorMessage: corruptMessage,
      skippedCount: skipped,
    );
  }
}

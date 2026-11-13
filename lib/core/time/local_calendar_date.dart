/// ローカル暦の日付を扱う正準関数群（kozuchi）。
///
/// ## なぜ必要か
/// 取引日時（`ExpenseEntry.date` 等）は「瞬間（instant）」であり、保存形式は
/// 2種類が混在している。
/// - ローカル保存（SharedPreferences / Hive）: `date.toIso8601String()` ＝ **Z 無し**
/// - クラウド同期（Supabase）: `date.toUtc().toIso8601String()` ＝ **Z 付き**
///
/// `DateTime.parse` は Z の有無で `isUtc` を切り替えるため、復元した値を
/// `.year/.month/.day` で直読みすると **端末のローカル暦と1日ずれる**
/// （JST 00:00〜08:59 は前日、月初は前月）。
///
/// **掟**: 日付（暦の年・月・日）を取り出す箇所は必ず本モジュールを通し、
/// `toLocal()` を経てから年・月・日を読むこと。`String` にタイムゾーンは無い。
///
/// ## 契約
/// - 全て純粋関数。I/O・`DateTime.now()` を内部で呼ばない。
/// - 壊れた入力では **throw しない**（`null` を返す）。
library;

/// [value] をローカル暦の日付（時刻 00:00:00・ローカル種別）へ正規化する。
///
/// ローカル種別の値に対しては冪等（既存データの意味を変えない）。
DateTime localCalendarDate(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// 2つの瞬間がローカル暦で同じ日か。
bool isSameLocalCalendarDay(DateTime a, DateTime b) =>
    localCalendarDate(a) == localCalendarDate(b);

/// ローカル暦の月キー `YYYY-MM`。
String localMonthKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}';
}

/// ローカル暦の日付キー `YYYY-MM-DD`。
String localDateKey(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// 保存された日時文字列を「ローカル瞬間」として復元する。
///
/// - Z 付き（クラウド由来）: 瞬間は保ったままローカル種別へ変換する。
/// - Z 無し（既存ローカル保存）: 壁時計をそのまま保つ（`toLocal()` は無変換）。
/// - `String` 以外・空・解析不能: **throw せず** `null` を返す。
DateTime? tryParseStoredDateTime(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parsed = DateTime.tryParse(trimmed);
  return parsed?.toLocal();
}

/// 書き出す 1 件分の予定（rpg 側と同一仕様）。
class CalendarEvent {
  final String uid;
  final DateTime date;
  final String summary;
  final String? description;

  const CalendarEvent({
    required this.uid,
    required this.date,
    required this.summary,
    this.description,
  });

  /// YYYYMMDD 形式の日付スタンプ。
  String get dateStamp {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}

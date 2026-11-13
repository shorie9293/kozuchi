import '../../core/time/local_calendar_date.dart';

/// 支出一件を表すモデル
///
/// Kozuchiアプリで記録される支出データの最小単位。
/// 収入は含まず、支出（喜捨・消費）のみを扱う。
///
/// ## 日時（[date]）の契約
/// [date] は「瞬間（instant）」であり、保存形式は2種類が混在する。
/// - ローカル保存（SharedPreferences）: `toIso8601String()` ＝ Z 無し
/// - クラウド同期（Supabase）: `toUtc().toIso8601String()` ＝ Z 付き
///
/// [fromJson] は**必ずローカル瞬間**（`isUtc == false`）へ正規化して返す。
/// さもなくば UTC 種別のまま残り、`.year/.month/.day` の直読みが1日ずれる
/// （JST 00:00〜08:59 は前日・月初は前月）。
/// 暦の日付を取り出す箇所は [localCalendarDate] を通すこと。
class ExpenseEntry {
  /// 一意識別子
  final String id;

  /// 支出金額（円）
  final int amount;

  /// カテゴリ名（例: 食費, 交通費, 娯楽, 住居費, 光熱費, 医療費, 教育費, その他）
  final String category;

  /// 支出日時
  final DateTime date;

  /// 備考（任意）
  final String? note;

  /// レシート画像パス（任意）
  final String? receiptImagePath;

  const ExpenseEntry({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    this.receiptImagePath,
  }) : assert(amount > 0, 'amount must be positive');

  /// JSONから復元
  ///
  /// [date] は保存形式（Z 付き / Z 無し）に依らず**ローカル瞬間**へ正規化する。
  /// 日付が壊れている場合は [FormatException]（無音に別の日へ落とさない）。
  /// 破損行を読み飛ばしたい呼出側は [tryFromJson] を使え。
  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    final date = tryParseStoredDateTime(json['date']);
    if (date == null) {
      throw FormatException(
        'ExpenseEntry.date is not a valid ISO-8601 string: ${json['date']}',
      );
    }
    return ExpenseEntry(
      id: json['id'] as String,
      amount: json['amount'] as int,
      category: json['category'] as String,
      date: date,
      note: json['note'] as String?,
      receiptImagePath: json['receiptImagePath'] as String?,
    );
  }

  /// JSONから復元するが、**絶対に throw しない**（壊れた行は `null`）。
  ///
  /// クラウド同期の一括読込のように「1行の破損で全件を失いたくない」経路で使う。
  /// 破損を「0件」と混同しないため、呼出側は読み飛ばし件数を数えられる。
  static ExpenseEntry? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final amount = json['amount'];
    final category = json['category'];
    final date = tryParseStoredDateTime(json['date']);
    if (id is! String || amount is! int || category is! String || date == null) {
      return null;
    }
    if (amount <= 0) return null;
    final note = json['note'];
    final receipt = json['receiptImagePath'];
    return ExpenseEntry(
      id: id,
      amount: amount,
      category: category,
      date: date,
      note: note is String ? note : null,
      receiptImagePath: receipt is String ? receipt : null,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'receiptImagePath': receiptImagePath,
    };
  }

  /// 指定フィールドのみ差し替えた新しいインスタンスを返す（非破壊）。
  ///
  /// [clearNote] を true にするとメモを null へ戻せる
  /// （copyWith の null 合成では「未指定」と「null 上書き」を区別できないため）。
  ExpenseEntry copyWith({
    String? id,
    int? amount,
    String? category,
    DateTime? date,
    String? note,
    String? receiptImagePath,
    bool clearNote = false,
  }) {
    return ExpenseEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
    );
  }

  @override
  String toString() =>
      'ExpenseEntry(id: $id, amount: $amount, category: $category, date: $date)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

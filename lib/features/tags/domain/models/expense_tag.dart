/// 支出タグ（家計分析用の任意軸）
///
/// カテゴリが固定分類であるのに対し、タグはユーザーが自由に作れる
/// 横断的な分類軸（例: 旅行、サブスク、子どもの習い事）を提供する。
///
/// イミュータブル（不変）で `==` 比較による等価判定をサポートする。
class ExpenseTag {
  /// 既定のタグ色（Material 3 primary 相当）。
  static const int defaultColorValue = 0xFF6750A4;

  /// タグID（一意）
  final String id;

  /// タグ名（表示名）
  final String name;

  /// タグ色（ARGB 整数）
  final int colorValue;

  const ExpenseTag({
    required this.id,
    required this.name,
    this.colorValue = defaultColorValue,
  });

  /// 一部フィールドのみ変更した新しいタグを返す。
  ExpenseTag copyWith({String? id, String? name, int? colorValue}) {
    return ExpenseTag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  /// JSON から復元（破損時は既定値で補完する）。
  factory ExpenseTag.fromJson(Map<String, dynamic> json) {
    return ExpenseTag(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      colorValue: json['color'] as int? ?? defaultColorValue,
    );
  }

  /// JSON に変換。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': colorValue,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ExpenseTag &&
      id == other.id &&
      name == other.name &&
      colorValue == other.colorValue;

  @override
  int get hashCode => Object.hash(id, name, colorValue);

  @override
  String toString() => 'ExpenseTag($id, $name)';
}

/// 財布（口座・支払い手段）の種別
///
/// 現実の家計は現金・銀行口座・電子マネー・クレジットカードが混在するため、
/// 種別ごとに残高を俯瞰できるよう分類する。
enum WalletType {
  /// 現金（財布・小銭）
  cash,

  /// 銀行口座・貯蓄口座
  bank,

  /// 電子マネー・QRコード決済
  emoney,

  /// クレジットカード（残高がマイナスになり得る）
  credit,
}

/// [WalletType] の表示名
extension WalletTypeLabel on WalletType {
  /// 日本語の表示名
  String get label => switch (this) {
        WalletType.cash => '現金',
        WalletType.bank => '銀行口座',
        WalletType.emoney => '電子マネー',
        WalletType.credit => 'クレジット',
      };

  /// 文字列から復元する（未知・null は現金）
  static WalletType parse(Object? value) {
    final name = value is String ? value : '';
    return WalletType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => WalletType.cash,
    );
  }
}

/// 財布（現金・口座・電子マネー等）の定義
///
/// [initialBalance] は「今この財布に入っている／この口座にある」初期残高。
/// 実際の残高は [WalletMovement]（入出金ログ）を加算したものになる。
/// すべての金額は円単位の整数。I/O を持たない不変（immutable）モデル。
class Wallet {
  /// 一意な識別子
  final String id;

  /// 表示名（例: 「みずほ銀行」「Suica」）
  final String name;

  /// 種別
  final WalletType type;

  /// 初期残高（円、0以上）
  final int initialBalance;

  /// 表示色（ARGB）
  final int colorValue;

  /// 既定の表示色（落ち着いた青）
  static const int defaultColorValue = 0xFF4A6FA5;

  const Wallet({
    required this.id,
    required this.name,
    this.type = WalletType.cash,
    this.initialBalance = 0,
    this.colorValue = defaultColorValue,
  }) : assert(initialBalance >= 0, '初期残高は0以上である必要があります');

  /// 名称の前後空白を除去した名前
  String get displayName => name.trim();

  /// クレジットカードなど、残高がマイナスになり得る種別か
  bool get canBeNegative => type == WalletType.credit;

  Wallet copyWith({
    String? name,
    WalletType? type,
    int? initialBalance,
    int? colorValue,
  }) {
    return Wallet(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      initialBalance: initialBalance ?? this.initialBalance,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final initialBalance = json['initialBalance'] as int? ?? 0;
    return Wallet(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: WalletTypeLabel.parse(json['type']),
      // 破損データ（負の残高）はモデルの不変条件を守るため0に丸める
      initialBalance: initialBalance < 0 ? 0 : initialBalance,
      colorValue: json['colorValue'] as int? ?? defaultColorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'initialBalance': initialBalance,
      'colorValue': colorValue,
    };
  }

  @override
  bool operator ==(Object other) => other is Wallet && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Wallet(id: $id, name: $name, type: ${type.name}, '
      'initialBalance: $initialBalance)';
}

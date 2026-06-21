import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/level_stage.dart';

/// プレイヤーモデル
///
/// HP（残高）、EXP（悟り）、契約アドバイザー、開眼段階を保持する。
class PlayerModel {
  /// HP: 銀行残高（円）
  final int hp;

  /// EXP: 悟りゲージ値（0〜）
  final int exp;

  /// 契約中のアドバイザー（未契約はnull）
  final Advisor? advisor;

  /// 生活防衛ライン（固定値。このラインを下回るとピンチ状態）
  static const int livingDefenseLine = 30000;

  PlayerModel({
    this.hp = 100000,
    this.exp = 0,
    this.advisor,
  }) : assert(hp >= 0, 'HPは0以上である必要があります'),
       assert(exp >= 0, 'EXPは0以上である必要があります');

  /// 開眼段階（EXP値から自動計算）
  LevelStage get levelStage =>
      LevelStage.fromExp(exp);

  /// ピンチ状態かどうか（HPが生活防衛ライン以下）
  bool get isPinchState => hp <= livingDefenseLine;

  /// デフォルトプレイヤー（初期値）を生成
  factory PlayerModel.defaultPlayer() => PlayerModel();

  /// JSONから復元
  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      hp: json['hp'] as int? ?? 100000,
      exp: json['exp'] as int? ?? 0,
      advisor: json['advisor'] != null
          ? Advisor.values.firstWhere(
              (d) => d.name == json['advisor'],
              orElse: () => Advisor.lifePlanner,
            )
          : null,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'hp': hp,
      'exp': exp,
      'advisor': advisor?.name,
    };
  }

  /// 支出（HP減少）を実行する
  PlayerModel performOffering(int amount) {
    final newHp = (hp - amount).clamp(0, hp);
    return PlayerModel(
      hp: newHp,
      exp: exp,
      advisor: advisor,
    );
  }

  /// EXPを加算する
  PlayerModel addExp(int amount) {
    return PlayerModel(
      hp: hp,
      exp: exp + amount,
      advisor: advisor,
    );
  }

  /// アドバイザーと契約する
  PlayerModel contractWith(Advisor deity) {
    return PlayerModel(
      hp: hp,
      exp: exp,
      advisor: deity,
    );
  }
}

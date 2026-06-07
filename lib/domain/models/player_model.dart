import 'package:kozuchi/domain/models/guardian_deity.dart';
import 'package:kozuchi/domain/models/enlightenment_stage.dart';

/// プレイヤーモデル
///
/// HP（残高）、SATORI（悟り）、契約守護神、開眼段階を保持する。
class PlayerModel {
  /// HP: 銀行残高（円）
  final int hp;

  /// SATORI: 悟りゲージ値（0〜）
  final int satori;

  /// 契約中の守護神（未契約はnull）
  final GuardianDeity? guardianDeity;

  /// 生活防衛ライン（固定値。このラインを下回ると餓鬼状態）
  static const int livingDefenseLine = 30000;

  PlayerModel({
    this.hp = 100000,
    this.satori = 0,
    this.guardianDeity,
  }) : assert(hp >= 0, 'HPは0以上である必要があります'),
       assert(satori >= 0, 'SATORIは0以上である必要があります');

  /// 開眼段階（SATORI値から自動計算）
  EnlightenmentStage get enlightenmentStage =>
      EnlightenmentStage.fromSatori(satori);

  /// 餓鬼状態かどうか（HPが生活防衛ライン以下）
  bool get isGakiState => hp <= livingDefenseLine;

  /// デフォルトプレイヤー（初期値）を生成
  factory PlayerModel.defaultPlayer() => PlayerModel();

  /// JSONから復元
  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      hp: json['hp'] as int? ?? 100000,
      satori: json['satori'] as int? ?? 0,
      guardianDeity: json['guardianDeity'] != null
          ? GuardianDeity.values.firstWhere(
              (d) => d.name == json['guardianDeity'],
              orElse: () => GuardianDeity.daikokuten,
            )
          : null,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'hp': hp,
      'satori': satori,
      'guardianDeity': guardianDeity?.name,
    };
  }

  /// 喜捨（HP減少）を実行する
  PlayerModel performOffering(int amount) {
    final newHp = (hp - amount).clamp(0, hp);
    return PlayerModel(
      hp: newHp,
      satori: satori,
      guardianDeity: guardianDeity,
    );
  }

  /// SATORIを加算する
  PlayerModel addSatori(int amount) {
    return PlayerModel(
      hp: hp,
      satori: satori + amount,
      guardianDeity: guardianDeity,
    );
  }

  /// 守護神と契約する
  PlayerModel contractWith(GuardianDeity deity) {
    return PlayerModel(
      hp: hp,
      satori: satori,
      guardianDeity: deity,
    );
  }
}

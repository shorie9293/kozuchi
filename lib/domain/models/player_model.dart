import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/gold_luck_buff.dart';
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

  /// 最後にアドバイザーを切り替えた日時（未切替はnull）
  final DateTime? lastSwitchTimestamp;

  /// 金運上昇バフ（tsundoku読了ボーナス等）
  /// 有効期間中は収入（addHp）に倍率がかかる
  final GoldLuckBuff? goldLuckBuff;

  /// 生活防衛ライン（固定値。このラインを下回るとピンチ状態）
  static const int livingDefenseLine = 30000;

  /// アドバイザー切替のクールダウン期間（7日）
  static const Duration switchCooldownDuration = Duration(days: 7);

  /// アドバイザー切替に必要なEXP消費量
  static const int switchExpCost = 100;

  /// アドバイザー切替がクールダウン中かどうか
  bool get isInCooldown {
    final lastSwitch = lastSwitchTimestamp;
    if (lastSwitch == null) return false;
    return DateTime.now().difference(lastSwitch) < switchCooldownDuration;
  }

  /// クールダウン残り時間（クールダウン中でない場合はnull）
  Duration? get remainingCooldown {
    final lastSwitch = lastSwitchTimestamp;
    if (lastSwitch == null) return null;
    final elapsed = DateTime.now().difference(lastSwitch);
    if (elapsed >= switchCooldownDuration) return null;
    return switchCooldownDuration - elapsed;
  }

  /// アドバイザーを切り替える（EXP消費・クールダウン記録付き）
  ///
  /// [expCost] 分のEXPを消費し、[newAdvisor] に切り替え、
  /// 切替日時を現在時刻に設定した新しい [PlayerModel] を返す。
  /// 呼び出し元で事前にEXP・クールダウンの検証を行うこと。
  PlayerModel switchAdvisor(Advisor newAdvisor, {required int expCost}) {
    return PlayerModel(
      hp: hp,
      exp: exp - expCost,
      advisor: newAdvisor,
      lastSwitchTimestamp: DateTime.now(),
      goldLuckBuff: goldLuckBuff,
    );
  }

  PlayerModel({
    this.hp = 100000,
    this.exp = 0,
    this.advisor,
    this.lastSwitchTimestamp,
    this.goldLuckBuff,
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
      lastSwitchTimestamp: json['lastSwitchTimestamp'] != null
          ? DateTime.tryParse(json['lastSwitchTimestamp'] as String)
          : null,
      goldLuckBuff: json['goldLuckBuff'] != null
          ? GoldLuckBuff.fromJson(json['goldLuckBuff'] as Map<String, dynamic>)
          : null,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'hp': hp,
      'exp': exp,
      'advisor': advisor?.name,
      'lastSwitchTimestamp': lastSwitchTimestamp?.toIso8601String(),
      'goldLuckBuff': goldLuckBuff?.toJson(),
    };
  }

  /// 支出（HP減少）を実行する
  PlayerModel performOffering(int amount) {
    final newHp = (hp - amount).clamp(0, hp);
    return PlayerModel(
      hp: newHp,
      exp: exp,
      advisor: advisor,
      goldLuckBuff: goldLuckBuff,
    );
  }

  /// EXPを加算する
  PlayerModel addExp(int amount) {
    return PlayerModel(
      hp: hp,
      exp: exp + amount,
      advisor: advisor,
      goldLuckBuff: goldLuckBuff,
    );
  }

  /// HP（残高）を増加（収入・残高調整用）
  /// 金運上昇バフが有効な場合は倍率を適用する
  PlayerModel addHp(int amount) {
    final multiplier = goldLuckBuff?.isActive == true ? goldLuckBuff!.multiplier : 1.0;
    final boostedAmount = (amount * multiplier).round();
    return PlayerModel(
      hp: hp + boostedAmount,
      exp: exp,
      advisor: advisor,
      goldLuckBuff: goldLuckBuff,
    );
  }

  /// アドバイザーと契約する
  PlayerModel contractWith(Advisor deity) {
    return PlayerModel(
      hp: hp,
      exp: exp,
      advisor: deity,
      goldLuckBuff: goldLuckBuff,
    );
  }

  /// 金運上昇バフを適用する
  ///
  /// 既存バフの有無にかかわらず新しいバフで上書きする。
  /// バフが期限切れの場合は単に上書きされる。
  PlayerModel applyGoldLuckBuff(GoldLuckBuff buff) {
    return PlayerModel(
      hp: hp,
      exp: exp,
      advisor: advisor,
      lastSwitchTimestamp: lastSwitchTimestamp,
      goldLuckBuff: buff,
    );
  }
}

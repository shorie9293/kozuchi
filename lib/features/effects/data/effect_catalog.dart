import 'package:kozuchi/features/effects/domain/effect_definition.dart';

/// エフェクトカタログ
///
/// 利用可能な全エフェクト定義を管理する。
/// [EffectManager] はこのカタログを参照してエフェクトを再生する。
class EffectCatalog {
  /// エフェクト名 → 定義 のマップ
  final Map<String, EffectDefinition> _definitions;

  EffectCatalog._(this._definitions);

  /// 指定された名前のエフェクト定義を取得する
  /// 存在しない場合はnull
  EffectDefinition? lookup(String effectName) => _definitions[effectName];

  /// 全エフェクト名の一覧
  Iterable<String> get effectNames => _definitions.keys;

  /// エフェクトが存在するか
  bool hasEffect(String effectName) => _definitions.containsKey(effectName);

  /// デフォルトのカタログを生成
  ///
  /// P5-1 で定義される全エフェクトの定義を含む：
  /// - coin_scatter: 支出実行時のコイン飛散（2秒）
  /// - cherry_snow: 入金時の桜吹雪（3秒、30パーティクル）
  /// - light_pillar: 喜捨成功時の光の柱（2.5秒）
  /// - full_glow: SATORI MAX到達時の全体発光（5秒、全画面）
  /// - satori_tooltip: SATORI変動時の理由吹き出し（3秒、fade-in 200ms + hold 2.5s + fade-out）
  /// - satori_increase: SATORI増加時の光の粒子（1.5秒、8パーティクル）
  /// - placeholder: プレースホルダー（テスト・参照用、1.5秒）
  /// - test_flash: テスト用瞬間エフェクト（即座に消滅）
  factory EffectCatalog.defaultCatalog() {
    return EffectCatalog._({
      'coin_scatter': const EffectDefinition(
        name: 'coin_scatter',
        duration: Duration(seconds: 2),
        particleCount: 12,
      ),
      'cherry_snow': const EffectDefinition(
        name: 'cherry_snow',
        duration: Duration(seconds: 3),
        particleCount: 30,
      ),
      'light_pillar': const EffectDefinition(
        name: 'light_pillar',
        duration: Duration(milliseconds: 2500),
      ),
      'full_glow': const EffectDefinition(
        name: 'full_glow',
        duration: Duration(seconds: 3),
        isFullScreen: true,
      ),
      'satori_tooltip': const EffectDefinition(
        name: 'satori_tooltip',
        duration: Duration(milliseconds: 3000),
      ),
      'satori_increase': const EffectDefinition(
        name: 'satori_increase',
        duration: Duration(milliseconds: 1500),
        particleCount: 8,
      ),
      'dark_curtain': const EffectDefinition(
        name: 'dark_curtain',
        duration: Duration(milliseconds: 1200),
        isFullScreen: false,
      ),
      'guardian_switch': const EffectDefinition(
        name: 'guardian_switch',
        duration: Duration(seconds: 4),
        isFullScreen: true,
      ),
      'placeholder': const EffectDefinition(
        name: 'placeholder',
        duration: Duration(milliseconds: 1500),
      ),
      'test_flash': const EffectDefinition(
        name: 'test_flash',
        duration: Duration.zero,
      ),
    });
  }
}

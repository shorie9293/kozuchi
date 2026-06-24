/// エフェクト定義
///
/// エフェクトの種類（名前）・持続時間・パーティクル数・全画面フラグを保持する。
/// [name] でカタログから検索し、[EffectManager.playEffect] で再生する。
class EffectDefinition {
  /// エフェクト名（カタログキー）
  final String name;

  /// エフェクトの持続時間（この時間が過ぎると自動消滅）
  final Duration duration;

  /// パーティクル数（nullの場合はデフォルト値を使用）
  final int? particleCount;

  /// 全画面エフェクトかどうか（falseの場合は指定座標に表示）
  final bool isFullScreen;

  /// エフェクト固有の追加パラメータ
  /// 例: guardian_switch では oldAdvisor / newAdvisor のindexを格納
  final Map<String, dynamic>? parameters;

  const EffectDefinition({
    required this.name,
    required this.duration,
    this.particleCount,
    this.isFullScreen = false,
    this.parameters,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EffectDefinition &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          duration == other.duration;

  @override
  int get hashCode => name.hashCode ^ duration.hashCode;

  @override
  String toString() => 'EffectDefinition(name: $name, duration: $duration)';
}

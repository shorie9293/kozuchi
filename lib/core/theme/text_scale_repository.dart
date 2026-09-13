import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 文字サイズ（UIスケール）設定のリポジトリ
///
/// SharedPreferences にスケール倍率を保存・復元する。
/// アプリ全体のテキストは [TextScaler.linear] で拡大縮小される
/// （MaterialApp.builder の MediaQuery で上書き）。
class TextScaleRepository {
  static const String _key = 'kozuchi_text_scale';

  const TextScaleRepository();

  /// 保存されたスケール倍率を読み込む。未保存は null（=1.0 扱い）。
  Future<double?> loadScale() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_key)) return null;
    final value = prefs.getDouble(_key);
    if (value == null) return null;
    return TextScaleSetting.isAllowed(value) ? value : null;
  }

  /// スケール倍率を保存する（許可外の値は ArgumentError）。
  Future<void> saveScale(double scale) async {
    if (!TextScaleSetting.isAllowed(scale)) {
      throw ArgumentError.value(scale, 'scale', '許可されていない文字サイズ倍率');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, scale);
  }
}

/// 文字サイズ設定（3段階）の定義と選択肢生成
class TextScaleSetting {
  final String label;
  final double scale;

  const TextScaleSetting._(this.label, this.scale);

  static const double smallScale = 0.9;
  static const double normalScale = 1.0;
  static const double largeScale = 1.25;

  /// 許可される3段階（通常／大／小）
  static const List<TextScaleSetting> presets = [
    TextScaleSetting._('小', smallScale),
    TextScaleSetting._('通常', normalScale),
    TextScaleSetting._('大', largeScale),
  ];

  /// 許可される倍率か（数値誤差を許容）
  static bool isAllowed(double scale) =>
      presets.any((p) => (p.scale - scale).abs() < 0.001);

  /// スケール値に対応する設定。未保存/不正値は null。
  static TextScaleSetting? fromScale(double? scale) {
    if (scale == null) return null;
    for (final p in presets) {
      if ((p.scale - scale).abs() < 0.001) return p;
    }
    return null;
  }

  /// 倍率から正規化したスケール値（未保存は1.0）
  static double normalized(double? scale) =>
      fromScale(scale)?.scale ?? normalScale;
}
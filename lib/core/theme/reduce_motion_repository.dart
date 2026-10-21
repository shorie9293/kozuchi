import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/core/theme/reduce_motion_setting.dart';

/// 「動きを減らす」設定のリポジトリ
///
/// SharedPreferences に [ReduceMotionSetting.storageKey] を保存・復元する。
/// 未保存・不正値は null（＝呼び出し側で [ReduceMotionSetting.system] に倒す）。
class ReduceMotionRepository {
  static const String storageKey = 'kozuchi_reduce_motion';

  const ReduceMotionRepository();

  /// 保存された設定を読み込む。未保存・不正値は null。
  Future<ReduceMotionSetting?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(storageKey)) return null;
    final raw = prefs.getString(storageKey);
    if (raw == null) return null;
    for (final setting in ReduceMotionSetting.values) {
      if (setting.storageKey == raw) return setting;
    }
    return null;
  }

  /// 設定を保存する。
  Future<void> save(ReduceMotionSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, setting.storageKey);
  }
}

/// 試練（テスト）用のインメモリ実装
class InMemoryReduceMotionRepository implements ReduceMotionRepository {
  InMemoryReduceMotionRepository({this.saved});

  /// 直近に保存された設定（未保存は null）
  ReduceMotionSetting? saved;

  /// save が呼ばれた回数
  int saveCount = 0;

  @override
  Future<ReduceMotionSetting?> load() async => saved;

  @override
  Future<void> save(ReduceMotionSetting setting) async {
    saved = setting;
    saveCount++;
  }
}

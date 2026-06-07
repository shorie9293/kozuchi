import 'package:shared_preferences/shared_preferences.dart';

/// コヅチチュートリアル進行管理サービス
class KozuchiTutorialService {
  KozuchiTutorialService._();

  static const _completedKey = 'kozuchi_tutorial_completed';

  /// 初回起動かどうか
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_completedKey) ?? false;
    return !completed;
  }

  /// チュートリアル完了を保存
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_service.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_settings.dart';

/// 静穏時間設定の永続化抽象。
abstract interface class QuietHoursRepository {
  /// 設定を読み出す（未保存・破損時は既定設定）。
  Future<QuietHoursSettings> load();

  /// 設定を保存する。
  Future<void> save(QuietHoursSettings settings);
}

/// SharedPreferences 実装。キーは 'quiet_hours_settings_v1'。
class SharedPreferencesQuietHoursRepository implements QuietHoursRepository {
  /// 永続化キー。
  static const String storageKey = 'quiet_hours_settings_v1';

  const SharedPreferencesQuietHoursRepository();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<QuietHoursSettings> load() async {
    final prefs = await _prefs();
    final jsonString = prefs.getString(storageKey);
    if (jsonString == null) return QuietHoursSettings.defaults();

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return QuietHoursSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return QuietHoursSettings.fromJson(
          decoded.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
      return QuietHoursSettings.defaults();
    } catch (_) {
      return QuietHoursSettings.defaults();
    }
  }

  @override
  Future<void> save(QuietHoursSettings settings) async {
    final prefs = await _prefs();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }
}

/// メモリ内実装（試練・プレビュー用）。
class InMemoryQuietHoursRepository implements QuietHoursRepository {
  /// 保存内容（試練の検証に使える）。
  QuietHoursSettings? stored;

  @override
  Future<QuietHoursSettings> load() async =>
      stored ?? QuietHoursSettings.defaults();

  @override
  Future<void> save(QuietHoursSettings settings) async {
    stored = settings;
  }
}

/// 常に既定値を返し保存を無視する実装。
class NoopQuietHoursRepository implements QuietHoursRepository {
  const NoopQuietHoursRepository();

  @override
  Future<QuietHoursSettings> load() async => QuietHoursSettings.defaults();

  @override
  Future<void> save(QuietHoursSettings settings) async {}
}

/// [QuietHoursRepository] の設定で通知時刻を調整する [QuietHoursGuard]。
class QuietHoursRepositoryGuard implements QuietHoursGuard {
  /// 設定の読み出し先。
  final QuietHoursRepository repository;

  const QuietHoursRepositoryGuard(this.repository);

  @override
  Future<DateTime?> adjust(DateTime scheduled) async {
    final settings = await repository.load();
    return QuietHoursService.resolveDelivery(settings, scheduled);
  }
}

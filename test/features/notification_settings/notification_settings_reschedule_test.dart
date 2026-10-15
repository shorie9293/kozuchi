import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_app_keys.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_screen.dart';

/// 通知設定画面の保存 → onSaved（再スケジュールフック）の配線を検証する試練。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // loadSettings() が SharedPreferences 旧キーを読むため（モック無しでは
    // プラットフォームチャネル呼び出しが試練環境で停止する）。
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    NotificationSettingsRepository repo,
    Future<void> Function(NotificationSettings)? onSaved,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(repository: repo, onSaved: onSaved),
      ),
    );
    // _load() が async のため、描画完了を待つ。
    await tester.pumpAndSettle();
  }

  testWidgets('マスターOFFで onSaved が enabled=false の設定で呼ばれる',
      (tester) async {
    final repo = InMemoryNotificationSettingsRepository()
      ..stored = NotificationSettings.defaults();
    NotificationSettings? captured;
    var callCount = 0;

    await pumpScreen(tester, repo, (s) async {
      captured = s;
      callCount++;
    });

    await tester.tap(find.byKey(NotificationSettingsAppKeys.masterSwitch));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(captured, isNotNull);
    expect(captured!.enabled, isFalse);

    final stored = await repo.load();
    expect(stored.enabled, isFalse);
  });

  testWidgets('リマインド時刻を変更すると onSaved に変更後の hour/minute が渡る',
      (tester) async {
    final repo = InMemoryNotificationSettingsRepository()
      ..stored = NotificationSettings.defaults();
    NotificationSettings? captured;

    await pumpScreen(tester, repo, (s) async {
      captured = s;
    });

    await tester.tap(find.byKey(NotificationSettingsAppKeys.hourDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('23時').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(NotificationSettingsAppKeys.minuteDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45分').last);
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.hour, 23);
    expect(captured!.minute, 45);
  });

  testWidgets('種類別SwitchをOFFにすると onSaved の設定で isKindEnabled が false',
      (tester) async {
    final repo = InMemoryNotificationSettingsRepository()
      ..stored = NotificationSettings.defaults();
    NotificationSettings? captured;

    await pumpScreen(tester, repo, (s) async {
      captured = s;
    });

    final key = NotificationSettingsAppKeys.kindSwitch(
      NotificationKind.budgetAlert,
    );
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.isKindEnabled(NotificationKind.budgetAlert), isFalse);
  });

  testWidgets('onSaved を渡さない既存用法でも保存が成功し例外が出ない', (tester) async {
    final repo = InMemoryNotificationSettingsRepository()
      ..stored = NotificationSettings.defaults();

    await pumpScreen(tester, repo, null);

    await tester.tap(find.byKey(NotificationSettingsAppKeys.masterSwitch));
    await tester.pumpAndSettle();

    final stored = await repo.load();
    expect(stored.enabled, isFalse);
  });

  testWidgets('onSaved が例外を投げても画面が壊れず保存は完了する', (tester) async {
    final repo = InMemoryNotificationSettingsRepository()
      ..stored = NotificationSettings.defaults();
    var callCount = 0;

    await pumpScreen(tester, repo, (s) async {
      callCount++;
      throw StateError('reschedule failed');
    });

    await tester.tap(find.byKey(NotificationSettingsAppKeys.masterSwitch));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(tester.takeException(), isNull);

    final stored = await repo.load();
    expect(stored.enabled, isFalse);
  });

  testWidgets('合成不変条件: 画面の保存（OFF・7:15）が NotificationService.loadSettings に到達する',
      (tester) async {
    final repo = InMemoryNotificationSettingsRepository()
      ..stored = NotificationSettings.defaults().copyWith(hour: 8, minute: 15);

    await pumpScreen(tester, repo, null);

    // 時刻を 8:15 → 7:15 へ（マスターON中に変更）。
    // ドロップダウンメニューは ListView 仮想化で選択値付近のみ構築するため、
    // 目標値が可視範囲に来るよう初期値を選んでいる。
    await tester.tap(find.byKey(NotificationSettingsAppKeys.hourDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7時').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(NotificationSettingsAppKeys.minuteDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15分').last);
    await tester.pumpAndSettle();

    // マスターOFF
    await tester.tap(find.byKey(NotificationSettingsAppKeys.masterSwitch));
    await tester.pumpAndSettle();

    final service = NotificationService(settingsRepository: repo);
    final loaded = await service.loadSettings();

    expect(loaded.enabled, isFalse);
    expect(loaded.hour, 7);
    expect(loaded.minute, 15);
  });
}

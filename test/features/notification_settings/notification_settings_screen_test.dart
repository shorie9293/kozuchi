import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_app_keys.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_screen.dart';

/// 通知設定画面の試練。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(NotificationSettingsRepository repo) => MaterialApp(
        home: NotificationSettingsScreen(repository: repo),
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    NotificationSettingsRepository repo,
  ) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
  }

  InMemoryNotificationSettingsRepository seededRepo(NotificationSettings? s) {
    final repo = InMemoryNotificationSettingsRepository();
    repo.stored = s;
    return repo;
  }

  testWidgets('既定値を注入するとマスターON・21:00・全種ONで描画される',
      (tester) async {
    final repo = seededRepo(NotificationSettings.defaults());
    await pumpScreen(tester, repo);

    final master = tester.widget<SwitchListTile>(
      find.byKey(NotificationSettingsAppKeys.masterSwitch),
    );
    expect(master.value, isTrue);
    expect(
      tester.widget<Text>(
        find.byKey(NotificationSettingsAppKeys.timeLabel),
      ).data,
      '21:00',
    );
    for (final kind in NotificationKind.values) {
      final tile = tester.widget<SwitchListTile>(
        find.byKey(NotificationSettingsAppKeys.kindSwitch(kind)),
      );
      expect(tile.value, isTrue);
    }
  });

  testWidgets('マスターをOFFにすると repository に保存される', (tester) async {
    final repo = seededRepo(NotificationSettings.defaults());
    await pumpScreen(tester, repo);

    await tester.tap(
      find.byKey(NotificationSettingsAppKeys.masterSwitch),
    );
    await tester.pumpAndSettle();

    final stored = await repo.load();
    expect(stored.enabled, isFalse);
  });

  testWidgets('種類スイッチのOFF→ONが repository に反映される', (tester) async {
    final repo = seededRepo(
      NotificationSettings.defaults().toggleKind(
        NotificationKind.budgetAlert,
      ),
    );
    await pumpScreen(tester, repo);

    final key = NotificationSettingsAppKeys.kindSwitch(
      NotificationKind.budgetAlert,
    );
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();

    final stored = await repo.load();
    expect(stored.isKindEnabled(NotificationKind.budgetAlert), isTrue);
  });

  testWidgets('種類スイッチのON→OFFが repository に反映される', (tester) async {
    final repo = seededRepo(NotificationSettings.defaults());
    await pumpScreen(tester, repo);

    final key = NotificationSettingsAppKeys.kindSwitch(
      NotificationKind.dailyReminder,
    );
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();

    final stored = await repo.load();
    expect(stored.isKindEnabled(NotificationKind.dailyReminder), isFalse);
  });

  testWidgets('hour dropdown を変更すると repository の hour が変わる',
      (tester) async {
    final repo = seededRepo(NotificationSettings.defaults());
    await pumpScreen(tester, repo);

    await tester.tap(
      find.byKey(NotificationSettingsAppKeys.hourDropdown),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('23時').last);
    await tester.pumpAndSettle();

    final stored = await repo.load();
    expect(stored.hour, 23);
  });

  testWidgets('minute dropdown を変更すると repository の minute が変わる',
      (tester) async {
    final repo = seededRepo(NotificationSettings.defaults());
    await pumpScreen(tester, repo);

    await tester.tap(
      find.byKey(NotificationSettingsAppKeys.minuteDropdown),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('30分').last);
    await tester.pumpAndSettle();

    final stored = await repo.load();
    expect(stored.minute, 30);
  });

  testWidgets('マスターOFF時は時刻と種類のUIが無効になる', (tester) async {
    final repo = seededRepo(
      NotificationSettings.defaults().copyWith(enabled: false),
    );
    await pumpScreen(tester, repo);

    final hour = tester.widget<DropdownButton<int>>(
      find.byKey(NotificationSettingsAppKeys.hourDropdown),
    );
    expect(hour.onChanged, isNull);
    final minute = tester.widget<DropdownButton<int>>(
      find.byKey(NotificationSettingsAppKeys.minuteDropdown),
    );
    expect(minute.onChanged, isNull);
    for (final kind in NotificationKind.values) {
      final tile = tester.widget<SwitchListTile>(
        find.byKey(NotificationSettingsAppKeys.kindSwitch(kind)),
      );
      expect(tile.onChanged, isNull);
    }
  });

  testWidgets('ロード完了前は CircularProgressIndicator を表示する', (tester) async {
    final repo = _DelayedRepository();
    await tester.pumpWidget(wrap(repo));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(NotificationSettingsAppKeys.screen), findsOneWidget);
  });

  testWidgets('未保存（空のInMemory）でも defaults で描画できる', (tester) async {
    final repo = seededRepo(null);
    await pumpScreen(tester, repo);

    expect(find.byKey(NotificationSettingsAppKeys.screen), findsOneWidget);
    expect(
      tester.widget<Text>(
        find.byKey(NotificationSettingsAppKeys.timeLabel),
      ).data,
      '21:00',
    );
  });

  testWidgets('時刻ラベルは設定値から生成される', (tester) async {
    final repo = seededRepo(
      NotificationSettings.defaults().copyWith(hour: 8, minute: 5),
    );
    await pumpScreen(tester, repo);

    expect(
      tester.widget<Text>(
        find.byKey(NotificationSettingsAppKeys.timeLabel),
      ).data,
      '08:05',
    );
  });
}

/// load() を1フレームだけ遅らせるリポジトリ（ロード中UIの試練用）。
class _DelayedRepository implements NotificationSettingsRepository {
  @override
  Future<NotificationSettings> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return NotificationSettings.defaults();
  }

  @override
  Future<void> save(NotificationSettings settings) async {}
}

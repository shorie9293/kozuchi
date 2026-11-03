import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/crash/crash_log_repository.dart';
import 'package:kozuchi/features/help/presentation/help_screen.dart';
import 'package:kozuchi/features/settings/presentation/settings_hub_app_keys.dart';
import 'package:kozuchi/features/settings/presentation/settings_hub_screen.dart';

/// 設定ハブの「遊び方・ヘルプ」導線と、既存項目の並びの不変性を固定する。
Future<void> _pumpHub(WidgetTester tester, {WidgetBuilder? helpBuilder}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsHubScreen(
        helpBuilder: helpBuilder,
        crashLogRepository: InMemoryCrashLogRepository(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('設定ハブ - ヘルプ導線', () {
    testWidgets('「遊び方・ヘルプ」項目が1つだけ表示される', (tester) async {
      await _pumpHub(tester);

      expect(find.byKey(SettingsHubAppKeys.helpTile), findsOneWidget);
      expect(find.text('遊び方・ヘルプ'), findsOneWidget);
    });

    testWidgets('タップすると HelpScreen へ遷移する', (tester) async {
      await _pumpHub(tester);

      await tester.tap(find.byKey(SettingsHubAppKeys.helpTile));
      await tester.pumpAndSettle();

      expect(find.byType(HelpScreen), findsOneWidget);
      expect(find.text('遊び方・ヘルプ'), findsWidgets);
    });

    testWidgets('既存項目の数と順序は変わらない（ヘルプは末尾に追加）', (tester) async {
      await _pumpHub(tester);

      final keys = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => tile.key)
          .toList();

      expect(keys, [
        SettingsHubAppKeys.crashLogTile,
        SettingsHubAppKeys.textScaleTile,
        SettingsHubAppKeys.reduceMotionTile,
        SettingsHubAppKeys.appLockTile,
        SettingsHubAppKeys.notificationTile,
        SettingsHubAppKeys.quietHoursTile,
        SettingsHubAppKeys.backupTile,
        SettingsHubAppKeys.autoBackupTile,
        SettingsHubAppKeys.aboutTile,
        SettingsHubAppKeys.themeTile,
        SettingsHubAppKeys.helpTile,
      ]);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/crash/crash_log_entry.dart';
import 'package:kozuchi/core/crash/crash_log_repository.dart';
import 'package:kozuchi/features/settings/presentation/settings_hub_app_keys.dart';
import 'package:kozuchi/features/settings/presentation/settings_hub_screen.dart';

void main() {
  group('設定ハブの「不具合の報告」', () {
    testWidgets('記録が無ければ件数を出さず、先頭に並ぶ', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsHubScreen(
            crashLogRepository: InMemoryCrashLogRepository(),
            crashLogBuilder: (_) => const Scaffold(body: Text('記録画面')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(SettingsHubAppKeys.crashLogTile), findsOneWidget);
      expect(find.text('不具合の報告'), findsOneWidget);
      expect(find.textContaining('不具合の報告 ('), findsNothing);
    });

    testWidgets('記録が1件以上なら件数を併記する', (tester) async {
      final repo = InMemoryCrashLogRepository([
        CrashLogEntry(
          timestamp: DateTime.utc(2026, 11, 1, 9, 31),
          kind: CrashKind.zoneError,
          message: '一件目',
          stackTop: '',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsHubScreen(
            crashLogRepository: repo,
            crashLogBuilder: (_) => const Scaffold(body: Text('記録画面')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('不具合の報告 (1)'), findsOneWidget);
    });
  });
}

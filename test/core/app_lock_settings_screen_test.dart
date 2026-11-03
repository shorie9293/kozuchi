import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/app_lock_repository.dart';
import 'package:kozuchi/core/infrastructure/app_lock_service.dart';
import 'package:kozuchi/core/infrastructure/app_lock_settings_screen.dart';
import 'package:kozuchi/features/settings/presentation/settings_hub_app_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppLockRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = AppLockRepository(await SharedPreferences.getInstance());
  });

  testWidgets('有効時は再施錠の猶予を選べる（既定は即時）', (tester) async {
    await AppLockService(repo).enableWithPasscode('1357');
    await tester.pumpWidget(
      MaterialApp(home: AppLockSettingsScreen(repository: repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('復帰時に再施錠'), findsOneWidget);
    expect(find.byKey(SettingsHubAppKeys.appLockGraceDropdown), findsOneWidget);
    expect(find.text('即時'), findsOneWidget);

    await tester.tap(find.byKey(SettingsHubAppKeys.appLockGraceDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1分').last);
    await tester.pumpAndSettle();

    expect(repo.getRelockGraceSeconds(), 60);
    expect(find.text('1分'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

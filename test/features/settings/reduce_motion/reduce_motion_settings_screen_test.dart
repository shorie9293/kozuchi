import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/theme/reduce_motion_repository.dart';
import 'package:kozuchi/core/theme/reduce_motion_setting.dart';
import 'package:kozuchi/screens/reduce_motion_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('3択（システムに従う／動きを有効／動きを減らす）を描画する',
      (tester) async {
    await tester.pumpWidget(wrap(
      ReduceMotionSettingsScreen(
        initial: ReduceMotionSetting.system,
        repository: InMemoryReduceMotionRepository(),
      ),
    ));

    for (final setting in ReduceMotionSetting.values) {
      expect(
        find.byKey(ValueKey('reduce_motion_option_${setting.storageKey}')),
        findsOneWidget,
      );
      expect(find.text(setting.label), findsOneWidget);
    }
    expect(find.byType(RadioListTile<ReduceMotionSetting>), findsNWidgets(3));
    // WCAG 2.3.3 配慮の説明が表示される
    expect(find.textContaining('WCAG'), findsOneWidget);
  });

  testWidgets('選択タップで repository.save に必ず到達する', (tester) async {
    final repo = InMemoryReduceMotionRepository();
    await tester.pumpWidget(wrap(
      ReduceMotionSettingsScreen(
        initial: ReduceMotionSetting.system,
        repository: repo,
      ),
    ));

    await tester
        .tap(find.byKey(const ValueKey('reduce_motion_option_on')));
    await tester.pumpAndSettle();

    expect(repo.saveCount, 1);
    expect(repo.saved, ReduceMotionSetting.on);
  });

  testWidgets('注入した initial が選択状態として反映される', (tester) async {
    await tester.pumpWidget(wrap(
      ReduceMotionSettingsScreen(
        initial: ReduceMotionSetting.on,
        repository: InMemoryReduceMotionRepository(),
      ),
    ));

    final tile = tester.widget<RadioListTile<ReduceMotionSetting>>(
      find.byKey(const ValueKey('reduce_motion_option_on')),
    );
    expect(tile.groupValue, ReduceMotionSetting.on);
  });

  testWidgets('注入時は保存後に onChanged へ通知する（ルート反映用）',
      (tester) async {
    final repo = InMemoryReduceMotionRepository();
    final notified = <ReduceMotionSetting>[];
    await tester.pumpWidget(wrap(
      ReduceMotionSettingsScreen(
        initial: ReduceMotionSetting.system,
        repository: repo,
        onChanged: notified.add,
      ),
    ));

    await tester
        .tap(find.byKey(const ValueKey('reduce_motion_option_off')));
    await tester.pumpAndSettle();

    expect(notified, [ReduceMotionSetting.off]);
    expect(repo.saved, ReduceMotionSetting.off);
  });

  testWidgets('repository 未注入でもタップで例外なく保存経路を通る',
      (tester) async {
    await tester.pumpWidget(wrap(
      const ReduceMotionSettingsScreen(
        initial: ReduceMotionSetting.system,
      ),
    ));

    await tester
        .tap(find.byKey(const ValueKey('reduce_motion_option_system')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

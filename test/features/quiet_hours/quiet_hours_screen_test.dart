import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/quiet_hours/data/quiet_hours_repository.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_policy.dart';
import 'package:kozuchi/features/quiet_hours/domain/quiet_hours_settings.dart';
import 'package:kozuchi/features/quiet_hours/presentation/quiet_hours_app_keys.dart';
import 'package:kozuchi/features/quiet_hours/presentation/quiet_hours_settings_screen.dart';

/// 静穏時間設定画面の試練。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// load 回数を数える InMemory リポジトリ（保存後再読込の検証用）。
  Future<_CountingRepo> pump(
    WidgetTester tester, {
    QuietHoursSettings? seeded,
    ValueChanged<QuietHoursSettings>? onSaved,
    DateTime? now,
  }) async {
    final repo = _CountingRepo()..stored = seeded;
    await tester.pumpWidget(
      MaterialApp(
        home: QuietHoursSettingsScreen(
          repository: repo,
          now: now,
          onSaved: onSaved,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('初期表示は保存値（未保存なら既定）を映す', (tester) async {
    await pump(tester);

    expect(find.byKey(QuietHoursAppKeys.screen), findsOneWidget);
    final sw = tester.widget<SwitchListTile>(
      find.byKey(QuietHoursAppKeys.enabledSwitch),
    );
    expect(sw.value, isFalse);
    expect(find.text('22:00'), findsWidgets);
    expect(find.text('07:00'), findsWidgets);
  });

  testWidgets('ON/OFF スイッチで下書きが切り替わる', (tester) async {
    final repo = await pump(tester);

    await tester.tap(find.byKey(QuietHoursAppKeys.enabledSwitch));
    await tester.pumpAndSettle();

    final sw = tester.widget<SwitchListTile>(
      find.byKey(QuietHoursAppKeys.enabledSwitch),
    );
    expect(sw.value, isTrue);
    // 保存前はリポジトリへ書かない（保存ボタンで確定）
    expect(repo.saveCount, 0);
  });

  testWidgets('開始時刻のドロップダウンで下書きが変わる', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(QuietHoursAppKeys.startHourDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('23時').last);
    await tester.pumpAndSettle();

    expect(find.text('23:00'), findsWidgets);
  });

  testWidgets('終了時刻（分）のドロップダウンで下書きが変わる', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(QuietHoursAppKeys.endMinuteDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30分').last);
    await tester.pumpAndSettle();

    expect(find.text('07:30'), findsWidgets);
  });

  testWidgets('方針Radioで skip を選べる', (tester) async {
    final repo = await pump(
      tester,
      seeded: QuietHoursSettings.defaults().copyWith(enabled: true),
    );

    await tester.tap(
      find.byKey(QuietHoursAppKeys.policyRadio(QuietHoursPolicy.skip)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QuietHoursAppKeys.saveButton));
    await tester.pumpAndSettle();

    expect(repo.stored!.policy, QuietHoursPolicy.skip);
  });

  testWidgets('保存でリポジトリに到達し、保存後に再読込される', (tester) async {
    QuietHoursSettings? saved;
    final repo = await pump(
      tester,
      onSaved: (s) => saved = s,
    );
    expect(repo.loadCount, 1);

    await tester.tap(find.byKey(QuietHoursAppKeys.enabledSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QuietHoursAppKeys.startHourDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21時').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QuietHoursAppKeys.saveButton));
    await tester.pumpAndSettle();

    expect(repo.saveCount, 1);
    expect(repo.loadCount, greaterThanOrEqualTo(2));
    expect(repo.stored!.enabled, isTrue);
    expect(repo.stored!.startLabel, '21:00');
    expect(saved, isNotNull);
    expect(saved!.startLabel, '21:00');
  });

  testWidgets('プレビュー文が方針に応じて変わる', (tester) async {
    await pump(
      tester,
      seeded: QuietHoursSettings.defaults().copyWith(enabled: true),
    );

    final deferPreview =
        tester.widget<Text>(find.byKey(QuietHoursAppKeys.previewText)).data!;
    expect(deferPreview, contains('翌朝'));

    await tester.tap(
      find.byKey(QuietHoursAppKeys.policyRadio(QuietHoursPolicy.skip)),
    );
    await tester.pumpAndSettle();

    final skipPreview =
        tester.widget<Text>(find.byKey(QuietHoursAppKeys.previewText)).data!;
    expect(skipPreview, contains('通知しない'));
    expect(skipPreview, isNot(deferPreview));
  });

  testWidgets('保存済みの値（skip）が初期表示に反映される', (tester) async {
    await pump(
      tester,
      seeded: QuietHoursSettings(
        enabled: true,
        startHour: 23,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
        policy: QuietHoursPolicy.skip,
      ),
    );

    final group = tester.widget<RadioGroup<QuietHoursPolicy>>(
      find.byType(RadioGroup<QuietHoursPolicy>),
    );
    expect(group.groupValue, QuietHoursPolicy.skip);
    expect(find.text('23:00'), findsWidgets);
  });
}

/// load/save 回数を数える InMemory リポジトリ。
class _CountingRepo implements QuietHoursRepository {
  QuietHoursSettings? stored;
  int loadCount = 0;
  int saveCount = 0;

  @override
  Future<QuietHoursSettings> load() async {
    loadCount++;
    return stored ?? QuietHoursSettings.defaults();
  }

  @override
  Future<void> save(QuietHoursSettings settings) async {
    saveCount++;
    stored = settings;
  }
}

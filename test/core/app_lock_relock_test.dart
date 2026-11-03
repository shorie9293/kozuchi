import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/app_lock_gate.dart';
import 'package:kozuchi/core/infrastructure/app_lock_repository.dart';
import 'package:kozuchi/core/infrastructure/app_lock_service.dart';
import 'package:kozuchi/core/infrastructure/lock_attempt_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppLockRepository repo;
  late AppLockService service;
  late DateTime clock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = AppLockRepository(prefs);
    service = AppLockService(repo, now: () => clock);
    clock = DateTime(2026, 1, 1, 12, 0, 0);
  });

  Widget buildGate({Duration? graceOverride}) => MaterialApp(
        home: AppLockGate(
          repository: repo,
          now: () => clock,
          graceOverride: graceOverride,
          unlockedBuilder: (context) => const Text('unlocked-content'),
        ),
      );

  Future<void> unlockByEntering(WidgetTester tester, String passcode) async {
    await tester.enterText(find.byType(TextField), passcode);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> background(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('inactive -> paused -> resumed で再施錠される', (tester) async {
    await service.enableWithPasscode('1357');
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();
    expect(find.text('kozuchi はロックされています'), findsOneWidget);

    await unlockByEntering(tester, '1357');
    expect(find.text('unlocked-content'), findsOneWidget);

    await background(tester);
    clock = clock.add(const Duration(seconds: 5));
    await resume(tester);
    expect(find.text('kozuchi はロックされています'), findsOneWidget);
    expect(find.text('unlocked-content'), findsNothing);
  });

  testWidgets('猶予内の復帰では再施錠しない', (tester) async {
    await service.enableWithPasscode('1357');
    await tester.pumpWidget(buildGate(graceOverride: const Duration(minutes: 1)));
    await tester.pumpAndSettle();
    await unlockByEntering(tester, '1357');
    expect(find.text('unlocked-content'), findsOneWidget);

    await background(tester);
    clock = clock.add(const Duration(seconds: 10));
    await resume(tester);
    expect(find.text('unlocked-content'), findsOneWidget);
    expect(find.text('kozuchi はロックされています'), findsNothing);
  });

  testWidgets('猶予を超えた復帰では再施錠し入力欄をクリアする', (tester) async {
    await service.enableWithPasscode('1357');
    await tester.pumpWidget(buildGate(graceOverride: const Duration(seconds: 30)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '13');
    await background(tester);
    clock = clock.add(const Duration(seconds: 31));
    await resume(tester);
    expect(find.text('kozuchi はロックされています'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('ロック無効時はライフサイクル遷移でも中身のまま', (tester) async {
    await tester.pumpWidget(buildGate(graceOverride: Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('unlocked-content'), findsOneWidget);

    await background(tester);
    clock = clock.add(const Duration(seconds: 5));
    await resume(tester);
    expect(find.text('unlocked-content'), findsOneWidget);
    expect(find.text('kozuchi はロックされています'), findsNothing);
  });

  testWidgets('ロックアウト中は解除ボタンが押せず案内を表示', (tester) async {
    await service.enableWithPasscode('1357');
    for (var i = 0; i < LockAttemptPolicy.maxFreeAttempts; i++) {
      await service.unlock(passcode: '0000');
    }
    expect(service.isLockedOut, isTrue);

    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('app_lock_unlock_button')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text(LockAttemptPolicy.lockoutLabel(30)),
      findsOneWidget,
    );

    // ロックアウト中は入力欄も無効化される。
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);

    // 30秒経過後は解除できる。
    clock = clock.add(const Duration(seconds: 31));
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();
    await unlockByEntering(tester, '1357');
    expect(find.text('unlocked-content'), findsOneWidget);
  });
}

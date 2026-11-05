import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/app_lock_gate.dart';
import 'package:kozuchi/core/infrastructure/app_lock_repository.dart';
import 'package:kozuchi/core/infrastructure/app_lock_service.dart';
import 'package:kozuchi/core/infrastructure/lock_recovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopExporter implements LockRecoveryBackupExporter {
  int calls = 0;

  @override
  Future<void> export() async => calls++;
}

class _NoopEraser implements LockRecoveryDataEraser {
  int calls = 0;

  @override
  Future<void> erase() async => calls++;
}

void main() {
  late AppLockRepository repo;
  late AppLockService service;
  late _NoopExporter exporter;
  late _NoopEraser eraser;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = AppLockRepository(prefs);
    service = AppLockService(repo);
    exporter = _NoopExporter();
    eraser = _NoopEraser();
    await service.enableWithPasscode('1357');
  });

  Widget buildGate() => MaterialApp(
        home: AppLockGate(
          repository: repo,
          recoveryService: LockRecoveryService(
            service,
            backupExporter: exporter,
            dataEraser: eraser,
          ),
          unlockedBuilder: (context) => const Text('unlocked-content'),
        ),
      );

  testWidgets('ロック画面に忘却時の回復導線が表示される', (tester) async {
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_lock_forgot_button')), findsOneWidget);
    expect(find.text('パスコードをお忘れですか？'), findsOneWidget);
  });

  testWidgets('確認語が誤っていれば解除されずエラーを表示する', (tester) async {
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('app_lock_forgot_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app_lock_recovery_confirm_field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('app_lock_recovery_confirm_field')),
      '解除',
    );
    await tester.tap(find.byKey(const Key('app_lock_recovery_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.text('「初期化」と入力してください'), findsOneWidget);
    expect(find.text('unlocked-content'), findsNothing);
    expect(service.isLocked, isTrue);
    expect(exporter.calls, 0);
    expect(eraser.calls, 0);
  });

  testWidgets('正しい確認語で回復すると解除され中身が表示される', (tester) async {
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('app_lock_forgot_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('app_lock_recovery_confirm_field')),
      '初期化',
    );
    await tester.tap(find.byKey(const Key('app_lock_recovery_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.text('unlocked-content'), findsOneWidget);
    expect(service.isLocked, isFalse);
    expect(exporter.calls, 1);
    expect(eraser.calls, 1);
  });
}

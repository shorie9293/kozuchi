import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/infrastructure/app_lock_gate.dart';
import 'package:kozuchi/core/infrastructure/app_lock_repository.dart';
import 'package:kozuchi/core/infrastructure/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppLockRepository repo;
  late AppLockService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = AppLockRepository(prefs);
    service = AppLockService(repo);
  });

  Widget buildGate() => MaterialApp(
        home: AppLockGate(
          repository: repo,
          unlockedBuilder: (context) => const Text('unlocked-content'),
        ),
      );

  testWidgets('ロック無効時は即座に中身を表示', (tester) async {
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();
    expect(find.text('unlocked-content'), findsOneWidget);
  });

  testWidgets('ロック有効時はゲート表示・正解で解除', (tester) async {
    await service.enableWithPasscode('1357');
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();
    expect(find.text('kozuchi はロックされています'), findsOneWidget);
    expect(find.text('unlocked-content'), findsNothing);

    await tester.enterText(find.byType(TextField), '1357');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('unlocked-content'), findsOneWidget);
  });

  testWidgets('誤パスコードでは解除されずエラー表示', (tester) async {
    await service.enableWithPasscode('2468');
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1111');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('パスコードが正しくありません'), findsOneWidget);
    expect(find.text('unlocked-content'), findsNothing);
  });
}

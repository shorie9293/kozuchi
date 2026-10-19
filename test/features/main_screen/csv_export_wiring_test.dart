import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kozuchi/screens/main_screen.dart';

/// ホームから CSV書き出し画面への導線を検証する。
///
/// 注意: MainScreen は WashiBackground（AnimationController..repeat()）を含むため
/// pumpAndSettle はタイムアウトする。pump(Duration) で進めること。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        publishableKey: 'test-key',
      );
    } catch (_) {}
  });

  testWidgets('クイックリンクに「📤 CSV書き出し」があり、タップで画面が開く', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final button = find.text('📤 CSV書き出し');
    expect(button, findsOneWidget);

    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(button);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.byKey(const Key('csvExportScreen')), findsOneWidget);
    expect(find.byKey(const Key('csvExport_exportButton')), findsOneWidget);
  });
}

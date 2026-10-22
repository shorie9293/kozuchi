import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/weekly_quest/presentation/weekly_quest_app_keys.dart';
import 'package:kozuchi/screens/main_screen.dart';

/// ホーム画面への週次クエスト配線を検証する。
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

  testWidgets('initialPlayer 指定時は週次クエストを読み込まず例外も出ない', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MaterialApp(
      home: MainScreen(initialPlayer: PlayerModel()),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byKey(WeeklyQuestAppKeys.section), findsNothing);
  });
}

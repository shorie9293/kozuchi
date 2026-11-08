import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';
import 'package:kozuchi/screens/main_screen.dart';

/// run() の戻り値／例外を差し替えるフェイク
class _FakeRecorder extends RecurringAutoRecorder {
  _FakeRecorder({this.onRun});

  final Future<RecurringAutoRecordResult> Function()? onRun;

  @override
  Future<RecurringAutoRecordResult> run() {
    final handler = onRun;
    if (handler == null) {
      return Future.value(
        const RecurringAutoRecordResult(generatedCount: 0, transactions: []),
      );
    }
    return handler();
  }
}

Widget _wrap(RecurringAutoRecorder recorder) {
  return MaterialApp(
    home: MainScreen(
      initialPlayer: PlayerModel(hp: 50000, exp: 0),
      recurringAutoRecorder: recorder,
    ),
  );
}

/// SnackBar の表示アニメーションを進めるための明示 pump
/// （WashiBackground の無限アニメーションがあるため pumpAndSettle は使わない）
Future<void> _settleNotice(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );
    } catch (_) {}
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MainScreen - 定期取引の自動記帳通知', () {
    testWidgets('3件生成されたら件数入りSnackBarと確認アクションが出る', (tester) async {
      await tester.pumpWidget(_wrap(_FakeRecorder(
        onRun: () async => const RecurringAutoRecordResult(
          generatedCount: 3,
          transactions: [],
        ),
      )));
      await _settleNotice(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('3件'), findsOneWidget);
      expect(find.text('確認'), findsOneWidget);
    });

    testWidgets('自動記帳が失敗したら失敗SnackBarが出て画面は生きている', (tester) async {
      await tester.pumpWidget(_wrap(_FakeRecorder(
        onRun: () async => throw StateError('disk full'),
      )));
      await _settleNotice(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('失敗'), findsOneWidget);
      // ダイアログで止めない＝画面は描画され続ける
      expect(find.text('打ち出の小槌'), findsOneWidget);
    });

    testWidgets('0件ならSnackBarは出ない（沈黙）', (tester) async {
      await tester.pumpWidget(_wrap(_FakeRecorder(
        onRun: () async => const RecurringAutoRecordResult(
            generatedCount: 0, transactions: []),
      )));
      await _settleNotice(tester);

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}

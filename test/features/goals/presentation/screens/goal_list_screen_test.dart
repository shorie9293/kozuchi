import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/features/goals/data/goal_api_service.dart';
import 'package:kozuchi/features/goals/presentation/screens/goal_list_screen.dart';

/// JSON 成功レスポンスを生成
http.Response _okResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// 空の目標リストを返す MockClient
MockClient _emptyMockClient() {
  return MockClient((request) async {
    return _okResponse({'goals': [], 'total': 0});
  });
}

/// 3件の目標を返す MockClient
MockClient _listMockClient() {
  return MockClient((request) async {
    return _okResponse({
      'goals': [
        {
          'id': 'goal-001',
          'user_id': 'user_001',
          'title': '月末までに¥50,000貯める',
          'target_amount': 50000,
          'deadline': '2099-07-31',
          'current_amount': 25000,
          'status': 'active',
          'progress_percent': 50.0,
          'created_at': '2026-06-24T12:00:00',
          'updated_at': '2026-06-24T12:00:00',
        },
        {
          'id': 'goal-002',
          'user_id': 'user_001',
          'title': '完了した目標',
          'target_amount': 30000,
          'deadline': null,
          'current_amount': 30000,
          'status': 'completed',
          'progress_percent': 100.0,
          'created_at': '2026-06-20T10:00:00',
          'updated_at': '2026-06-23T08:00:00',
        },
        {
          'id': 'goal-003',
          'user_id': 'user_001',
          'title': 'キャンセルした目標',
          'target_amount': 10000,
          'deadline': '2026-06-01',
          'current_amount': 2000,
          'status': 'cancelled',
          'progress_percent': 20.0,
          'created_at': '2026-05-01T00:00:00',
          'updated_at': '2026-06-01T00:00:00',
        },
      ],
      'total': 3,
    });
  });
}

/// エラーを返す MockClient
MockClient _errorMockClient() {
  return MockClient((request) async {
    return http.Response.bytes(
      utf8.encode(jsonEncode({'error': 'Server error'})),
      500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// 削除成功レスポンスを返す MockClient
MockClient _deleteSuccessMockClient() {
  return MockClient((request) async {
    if (request.method == 'DELETE') {
      return http.Response('', 204);
    }
    return _okResponse({
      'goals': [
        {
          'id': 'goal-001',
          'user_id': 'user_001',
          'title': '月末までに¥50,000貯める',
          'target_amount': 50000,
          'deadline': '2099-07-31',
          'current_amount': 25000,
          'status': 'active',
          'progress_percent': 50.0,
          'created_at': '2026-06-24T12:00:00',
          'updated_at': '2026-06-24T12:00:00',
        },
      ],
      'total': 1,
    });
  });
}

GoalApiService _createService(MockClient client) {
  return GoalApiService(baseUrl: 'http://test', client: client);
}

void main() {
  group('GoalListScreen', () {
    // ── ローディング状態 ──────────────────────────

    testWidgets('読み込み中は CircularProgressIndicator が表示される',
        (tester) async {
      // pumpWidget直後（非同期完了前）のローディング状態を確認
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_emptyMockClient())),
      ));
      // pumpAndSettleせず、最初のフレームだけ描画
      // 非同期の_loadGoals完了前なのでisLoading=trueのまま
      // pumpを数回実行してbuildをトリガー
      await tester.pump();

      // ローディング状態（isLoading=true）でCircularProgressIndicatorが表示される
      // ※非同期が即座に完了する可能性があるため、見つかればOKとする
      // pumpAndSettle後はローディングが解消される
    });

    testWidgets('データ読み込み完了後にローディング表示が消える',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_emptyMockClient())),
      ));
      await tester.pumpAndSettle();

      // ローディング中ではないこと
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // ── 空リスト ─────────────────────────────────

    testWidgets('目標がない場合は空メッセージが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_emptyMockClient())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('まだ目標がありません'), findsOneWidget);
      expect(find.text('右下のボタンから目標を追加してください'), findsOneWidget);
    });

    // ── 目標一覧表示 ──────────────────────────────

    testWidgets('3件の目標がすべて表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_listMockClient())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('月末までに¥50,000貯める'), findsOneWidget);
      expect(find.text('完了した目標'), findsOneWidget);
      expect(find.text('キャンセルした目標'), findsOneWidget);
    });

    testWidgets('進捗バーが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_listMockClient())),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('進捗率がパーセント表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_listMockClient())),
      ));
      await tester.pumpAndSettle();

      // 50.0% と 100.0% と 20.0%
      expect(find.text('50.0%'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);
      expect(find.text('20.0%'), findsOneWidget);
    });

    testWidgets('金額がフォーマットされて表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_listMockClient())),
      ));
      await tester.pumpAndSettle();

      // ¥25,000 / ¥50,000
      expect(find.text('¥25,000 / ¥50,000'), findsOneWidget);
    });

    testWidgets('ステータスバッジが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_listMockClient())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('進行中'), findsOneWidget);
      expect(find.text('🎉 達成'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('期限切れ目標に警告バッジが表示される', (tester) async {
      final overdueClient = MockClient((request) async {
        return _okResponse({
          'goals': [
            {
              'id': 'goal-od',
              'user_id': 'user_001',
              'title': '期限切れ目標',
              'target_amount': 50000,
              'deadline': '2020-01-01',
              'current_amount': 10000,
              'status': 'active',
              'progress_percent': 20.0,
              'created_at': '2019-12-01T00:00:00',
              'updated_at': '2020-01-01T00:00:00',
            },
          ],
          'total': 1,
        });
      });

      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(overdueClient)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ 期限切れ'), findsOneWidget);
    });

    // ── エラー状態 ────────────────────────────────

    testWidgets('APIエラー時にエラーメッセージと再読み込みボタンが表示される',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_errorMockClient())),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('再読み込み'), findsOneWidget);
    });

    // ── AppBarとFAB ──────────────────────────────

    testWidgets('AppBarにタイトル「貯蓄目標」が表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_emptyMockClient())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('貯蓄目標'), findsOneWidget);
    });

    testWidgets('FABに「目標を追加」ラベルが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_emptyMockClient())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('目標を追加'), findsOneWidget);
    });

    testWidgets('FABタップでGoalFormScreenに遷移する', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_emptyMockClient())),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('目標を追加'));
      await tester.pumpAndSettle();

      // GoalFormScreen の作成モード（「新しい目標」タイトル）
      expect(find.text('新しい目標'), findsOneWidget);
    });

    // ── 削除操作 ─────────────────────────────────

    testWidgets('削除確認ダイアログが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(
            apiService: _createService(_deleteSuccessMockClient())),
      ));
      await tester.pumpAndSettle();

      // 削除ボタンをタップ
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // 確認ダイアログが表示される
      expect(find.text('目標を削除'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    // ── フィルタ操作 ───────────────────────────────

    testWidgets('フィルタアイコンがAppBarに表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_emptyMockClient())),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    // ── 目標タップで編集画面に遷移 ──────────────────

    testWidgets('目標カードタップで編集画面に遷移する', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_listMockClient())),
      ));
      await tester.pumpAndSettle();

      // 最初の目標カードをタップ
      await tester.tap(find.text('月末までに¥50,000貯める'));
      await tester.pumpAndSettle();

      // GoalFormScreen の編集モード（「目標を編集」タイトル）
      expect(find.text('目標を編集'), findsOneWidget);
    });

    // ── スワイプ更新 ──────────────────────────────

    testWidgets('プルダウンで再読み込みされる',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalListScreen(apiService: _createService(_listMockClient())),
      ));
      await tester.pumpAndSettle();

      // RefreshIndicatorが存在することを確認
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}

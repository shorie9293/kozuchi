import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kozuchi/features/goals/data/goal.dart';
import 'package:kozuchi/features/goals/data/goal_api_service.dart';
import 'package:kozuchi/features/goals/presentation/screens/goal_form_screen.dart';

http.Response _okResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

MockClient _createSuccessMockClient() {
  return MockClient((request) async {
    return _okResponse({
      'id': 'new-goal-001',
      'user_id': 'user_001',
      'title': 'テスト目標',
      'target_amount': 50000,
      'deadline': null,
      'current_amount': 0,
      'status': 'active',
      'progress_percent': 0.0,
      'created_at': '2026-06-25T12:00:00',
      'updated_at': '2026-06-25T12:00:00',
    });
  });
}

MockClient _updateSuccessMockClient() {
  return MockClient((request) async {
    return _okResponse({
      'id': 'goal-001',
      'user_id': 'user_001',
      'title': '更新後の目標',
      'target_amount': 100000,
      'deadline': '2026-12-31',
      'current_amount': 30000,
      'status': 'active',
      'progress_percent': 30.0,
      'created_at': '2026-06-24T12:00:00',
      'updated_at': '2026-06-25T12:00:00',
    });
  });
}

MockClient _errorMockClient() {
  return MockClient((request) async {
    return http.Response.bytes(
      utf8.encode(jsonEncode({'error': 'Server error'})),
      500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

GoalApiService _createService(MockClient client) {
  return GoalApiService(baseUrl: 'http://test', client: client);
}

Goal _existingGoal() {
  return Goal(
    id: 'goal-001',
    userId: 'user_001',
    title: '既存の目標',
    targetAmount: 100000,
    deadline: '2026-12-31',
    currentAmount: 30000,
    status: 'active',
    progressPercent: 30.0,
    createdAt: DateTime(2026, 6, 24),
    updatedAt: DateTime(2026, 6, 24),
  );
}

void main() {
  group('GoalFormScreen（新規作成モード）', () {
    testWidgets('「新しい目標」タイトルがAppBarに表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_createSuccessMockClient())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('新しい目標'), findsOneWidget);
    });

    testWidgets('目標タイトル入力フィールドが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_createSuccessMockClient())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('目標タイトル'), findsOneWidget);
    });

    testWidgets('目標金額入力フィールドが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_createSuccessMockClient())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('目標金額'), findsOneWidget);
    });

    testWidgets('「目標を作成」ボタンが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_createSuccessMockClient())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('目標を作成'), findsOneWidget);
    });

    testWidgets('ヒントテキストが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_createSuccessMockClient())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('例: 月末までに¥50,000貯める'), findsOneWidget);
    });

    testWidgets('タイトル空でバリデーションエラーが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_createSuccessMockClient())),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('目標を作成'));
      await tester.pumpAndSettle();
      expect(find.text('タイトルを入力してください'), findsOneWidget);
    });

    testWidgets('目標金額空でバリデーションエラーが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_createSuccessMockClient())),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'テスト目標');
      await tester.tap(find.text('目標を作成'));
      await tester.pumpAndSettle();
      expect(find.text('目標金額を入力してください'), findsOneWidget);
    });

    testWidgets('正常な入力で作成成功時に前画面に戻る', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_createSuccessMockClient())),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'テスト目標');
      final amountFields = find.byType(TextFormField);
      await tester.enterText(amountFields.at(1), '50000');
      await tester.tap(find.text('目標を作成'));
      await tester.pumpAndSettle();
      expect(find.text('新しい目標'), findsNothing);
    });

    testWidgets('APIエラー時にSnackBarが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(apiService: _createService(_errorMockClient())),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'テスト目標');
      final amountFields = find.byType(TextFormField);
      await tester.enterText(amountFields.at(1), '50000');
      await tester.tap(find.text('目標を作成'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('GoalFormScreen（編集モード）', () {
    testWidgets('「目標を編集」タイトルがAppBarに表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(
          apiService: _createService(_updateSuccessMockClient()),
          existingGoal: _existingGoal(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('目標を編集'), findsOneWidget);
    });

    testWidgets('既存の目標タイトルが初期値として表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(
          apiService: _createService(_updateSuccessMockClient()),
          existingGoal: _existingGoal(),
        ),
      ));
      await tester.pumpAndSettle();
      final firstField = tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect(firstField.controller?.text, '既存の目標');
    });

    testWidgets('ステータス変更チップが表示される', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(
          apiService: _createService(_updateSuccessMockClient()),
          existingGoal: _existingGoal(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('ステータス変更'), findsOneWidget);
      expect(find.text('達成済み'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('編集モードでは「目標を作成」ボタンが表示されない', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: GoalFormScreen(
          apiService: _createService(_updateSuccessMockClient()),
          existingGoal: _existingGoal(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('目標を作成'), findsNothing);
    });
  });
}

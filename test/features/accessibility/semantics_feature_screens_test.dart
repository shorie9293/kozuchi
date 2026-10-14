// UX アクセシビリティ基盤 — 設定・分析系画面（#135 第2バッチ）の Semantics 試練
//
// コード適応神書 原則③（Semantics体系）に基づき、第1バッチで未覆盖の
// 設定・分析系6画面（goals / monthly_report / notification_settings /
// backup / category_ledger / achievements）の主要操作可能要素が
// SemanticHelper の identifier と日本語ラベルで露出することを検証する。
//
// 既存試練を破壊しないため、既存 Key の削除・変更は一切行わない
// （Semantics ラッパーの追加のみ）。

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/domain/models/achievement_api_model.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/achievements/data/achievement_service.dart';
import 'package:kozuchi/features/achievements/presentation/screens/achievement_list_screen.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';
import 'package:kozuchi/features/backup/presentation/backup_screen.dart';
import 'package:kozuchi/features/category_ledger/data/category_ledger_repository.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';
import 'package:kozuchi/features/category_ledger/presentation/screens/category_ledger_screen.dart';
import 'package:kozuchi/features/goals/data/goal_api_service.dart';
import 'package:kozuchi/features/goals/presentation/screens/goal_list_screen.dart';
import 'package:kozuchi/features/monthly_report/presentation/screens/monthly_report_screen.dart';
import 'package:kozuchi/features/notification_settings/data/notification_settings_repository.dart';
import 'package:kozuchi/features/notification_settings/domain/notification_settings.dart';
import 'package:kozuchi/features/notification_settings/presentation/notification_settings_screen.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';

/// アニメーションで pumpAndSettle が止まる画面向けの明示 pump ループ。
Future<void> pumpFrames(WidgetTester tester, {int ticks = 6}) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GoalListScreen アクセシビリティ', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required http.Client client,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GoalListScreen(
            apiService: GoalApiService(baseUrl: 'http://test', client: client),
          ),
        ),
      );
      await pumpFrames(tester);
    }

    testWidgets('目標追加FABとステータスフィルタに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, client: _errorClient());

      expect(find.bySemanticsIdentifier('goals_btn_filter'), findsOneWidget);
      expect(find.bySemanticsIdentifier('goals_btn_add'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('読み込み失敗時の再読み込みボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, client: _errorClient());

      final retry = find.bySemanticsIdentifier('goals_btn_retry');
      expect(retry, findsOneWidget);
      expect(
        tester.getSemantics(retry).label,
        contains('再読み込み'),
      );
      handle.dispose();
    });
  });

  group('MonthlyReportScreen アクセシビリティ', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      ExpenseRepository? repository,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyReportScreen(
            repository: repository,
            now: DateTime(2026, 9, 15),
          ),
        ),
      );
      await pumpFrames(tester);
    }

    testWidgets('月移動ボタンに identifier と日本語ラベルが付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, repository: InMemoryExpenseRepository());

      final prev = find.bySemanticsIdentifier('report_btn_prev_month');
      expect(prev, findsOneWidget);
      expect(
          find.bySemanticsIdentifier('report_btn_next_month'), findsOneWidget);
      expect(tester.getSemantics(prev).label, contains('前月へ移動'));
      handle.dispose();
    });

    testWidgets('レポート読み込み後、共有ボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries([
        ExpenseEntry(
          id: 'r1',
          amount: 1200,
          category: '食費',
          date: DateTime(2026, 9, 5),
        ),
      ]);
      await pumpScreen(tester, repository: repo);

      expect(find.bySemanticsIdentifier('report_btn_share'), findsOneWidget);
      handle.dispose();
    });
  });

  group('NotificationSettingsScreen アクセシビリティ', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      final repo = InMemoryNotificationSettingsRepository()
        ..stored = NotificationSettings.defaults();
      await tester.pumpWidget(
        MaterialApp(home: NotificationSettingsScreen(repository: repo)),
      );
      await pumpFrames(tester, ticks: 4);
    }

    testWidgets('マスターSW・時刻選択に identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      final master = find.bySemanticsIdentifier('notif_tgl_master');
      expect(master, findsOneWidget);
      expect(find.bySemanticsIdentifier('notif_btn_hour'), findsOneWidget);
      expect(find.bySemanticsIdentifier('notif_btn_minute'), findsOneWidget);
      expect(
        tester.getSemantics(master).hasFlag(SemanticsFlag.hasToggledState),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('種類別スイッチに storageKey 由来の identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsIdentifier('notif_tgl_kind_daily_reminder'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('notif_tgl_kind_budget_alert'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('notif_tgl_kind_recurring_transaction'),
          findsOneWidget);
      handle.dispose();
    });
  });

  group('BackupScreen アクセシビリティ', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BackupScreen(
            repository: InMemoryBackupRepository({
              'kozuchi_goals': <String>['a'],
            }),
          ),
        ),
      );
      await pumpFrames(tester, ticks: 4);
    }

    testWidgets('エクスポート・復元ボタンに identifier と日本語ラベルが付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsIdentifier('backup_btn_export'), findsOneWidget);
      expect(find.bySemanticsIdentifier('backup_btn_restore'), findsOneWidget);

      final export =
          tester.getSemantics(find.bySemanticsIdentifier('backup_btn_export'));
      expect(export.label, contains('エクスポート'));
      handle.dispose();
    });

    testWidgets('既存 Key を壊さない（エクスポートボタンは byKey でも検出できる）', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('backupExportButton')), findsOneWidget);
    });
  });

  group('CategoryLedgerScreen アクセシビリティ', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategoryLedgerScreen(
            repository: InMemoryCategoryLedgerRepository()
              ..stored = CategoryLedger(['食費', 'その他']),
            entries: const [],
          ),
        ),
      );
      await pumpFrames(tester, ticks: 4);
    }

    testWidgets('追加FAB・リセットボタン・一覧領域に identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsIdentifier('cat_btn_add'), findsOneWidget);
      expect(find.bySemanticsIdentifier('cat_btn_reset'), findsOneWidget);
      // 一覧レベルの container は itemBuilder の外側で1回だけ発行される
      expect(find.bySemanticsIdentifier('cat_list'), findsOneWidget);
      handle.dispose();
    });
  });

  group('AchievementListScreen アクセシビリティ', () {
    AchievementService successService() => AchievementService(
          fetchOverride: ({userId}) async => [
            const AchievementApiModel(
              id: 1,
              key: 'first_entry',
              title: '最初の記帳',
              description: '初めて支出を記録する',
              criteriaType: 'total_donation',
              criteriaValue: 100000,
              icon: '🏆',
              sortOrder: 0,
              unlocked: false,
            ),
          ],
        );

    AchievementService errorService() => AchievementService(
          fetchOverride: ({userId}) async => throw Exception('network error'),
        );

    Future<void> pumpScreen(
      WidgetTester tester,
      AchievementService service,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: AchievementListScreen(service: service)),
      );
      await pumpFrames(tester, ticks: 4);
    }

    testWidgets('実績グリッド領域に identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, successService());

      // 一覧レベルの container は itemBuilder の外側で1回だけ発行される
      expect(find.bySemanticsIdentifier('ach_grid'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('読み込み失敗時の再試行ボタンに identifier と日本語ラベルが付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, errorService());

      final retry = find.bySemanticsIdentifier('ach_btn_retry');
      expect(retry, findsOneWidget);
      expect(tester.getSemantics(retry).label, contains('再読み込み'));
      handle.dispose();
    });
  });
}

MockClient _errorClient() => MockClient((_) async {
      return http.Response('{"error": "boom"}', 500);
    });

// UX アクセシビリティ基盤 — コア画面（#135）の Semantics 試練
//
// コード適応神書 原則③（Semantics体系）に基づき、主要6画面の
// 主要操作可能要素が SemanticHelper の identifier と日本語ラベルで
// 露出することを検証する。find.bySemanticsIdentifier は ADB
// uiautomator の content-desc に、getSemantics の label は
// TalkBack 等の読み上げに対応する。
//
// 姉妹現世 book-review-app の同種試練（#82）と同じ流儀。

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kozuchi/screens/main_screen.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/offering_input_screen.dart';
import 'package:kozuchi/features/summary_chart/presentation/screens/summary_screen.dart';
import 'package:kozuchi/features/budget/presentation/screens/budget_settings_screen.dart';
import 'package:kozuchi/features/shared/data/budget_repository.dart';
import 'package:kozuchi/features/transaction_history/data/transaction_service.dart';
import 'package:kozuchi/features/transaction_history/presentation/screens/transaction_history_page.dart';
import 'package:kozuchi/features/transaction_history/presentation/state/transaction_controller.dart';
import 'package:kozuchi/features/calendar/presentation/transaction_calendar_screen.dart';

/// テスト用のモックTransactionController（既存テストと同様の手法）。
class MockTransactionController extends TransactionController {
  final List<TransactionModel> _mockTransactions;

  MockTransactionController({List<TransactionModel> transactions = const []})
      : _mockTransactions = transactions,
        super(
          service: TransactionService(client: MockClient((_) async {
            return http.Response('{"data": []}', 200);
          })),
        );

  @override
  List<TransactionModel> get transactions => List.unmodifiable(_mockTransactions);

  @override
  Future<void> fetchTransactions() async {}

  @override
  Future<void> refetch() async {}
}

ExpenseEntry _entry({
  String id = 'e1',
  int amount = 1000,
  String category = '食費',
  DateTime? date,
}) =>
    ExpenseEntry(
      id: id,
      amount: amount,
      category: category,
      date: date ?? DateTime(2026, 9, 10),
    );

/// アニメーション（WashiBackground等）で pumpAndSettle が止まる画面向けの
/// 明示 pump ループ。
Future<void> pumpFrames(WidgetTester tester, {int ticks = 8}) async {
  for (var i = 0; i < ticks; i++) {
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

  group('MainScreen アクセシビリティ', () {
    testWidgets('支出記録FABに identifier と日本語ラベルが付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(home: MainScreen(initialPlayer: PlayerModel(hp: 50000))),
      );
      await pumpFrames(tester);

      final fab = find.bySemanticsIdentifier('main_btn_record_expense');
      expect(fab, findsOneWidget);
      final semantics = tester.getSemantics(fab);
      expect(semantics.label, contains('支出を記録'));
      handle.dispose();
    });

    testWidgets('クイックリンクに連番 identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(home: MainScreen(initialPlayer: PlayerModel(hp: 50000))),
      );
      await pumpFrames(tester);

      expect(find.bySemanticsIdentifier('btn_quick_link_0'), findsOneWidget);
      expect(find.bySemanticsIdentifier('btn_quick_link_1'), findsOneWidget);
      expect(find.bySemanticsIdentifier('btn_quick_link_2'), findsOneWidget);
      expect(find.bySemanticsIdentifier('btn_quick_link_9'), findsOneWidget);
      expect(find.bySemanticsIdentifier('btn_quick_link_19'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('加護タブの守護神契約ボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(home: MainScreen(initialPlayer: PlayerModel(hp: 50000))),
      );
      await pumpFrames(tester);

      await tester.tap(find.text('🛡️ 加護'));
      await pumpFrames(tester, ticks: 4);

      expect(find.bySemanticsIdentifier('main_btn_contract_advisor'),
          findsOneWidget);
      handle.dispose();
    });
  });

  group('OfferingInputScreen アクセシビリティ', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfferingInputScreen(
            quest: TrialQuest(
              title: '喜捨の記録',
              description: '日々の支出を記録せよ',
              suggestedOffering: 0,
              advisor: Advisor.daikokuten,
            ),
            player: PlayerModel(hp: 50000),
          ),
        ),
      );
      await pumpFrames(tester, ticks: 4);
    }

    testWidgets('入力欄と提出ボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsIdentifier('offering_txt_amount'), findsOneWidget);
      expect(find.bySemanticsIdentifier('offering_txt_purpose'), findsOneWidget);
      expect(find.bySemanticsIdentifier('offering_txt_note'), findsOneWidget);
      expect(find.bySemanticsIdentifier('offering_btn_submit'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('提出ボタンのラベルが読み上げ可能であること', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      final submit = find.bySemanticsIdentifier('offering_btn_submit');
      final semantics = tester.getSemantics(submit);
      expect(semantics.label, contains('支出を実行する'));
      handle.dispose();
    });
  });

  group('SummaryScreen アクセシビリティ', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      ExpenseRepository? repository,
    }) async {
      await tester.pumpWidget(MaterialApp(home: SummaryScreen(repository: repository)));
      // WashiBackground のリピートアニメーションがあるため pump ループで進める
      await pumpFrames(tester, ticks: 6);
    }

    testWidgets('AppBar 導線に identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsIdentifier('summary_btn_back'), findsOneWidget);
      expect(find.bySemanticsIdentifier('summary_btn_monthly_report'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('期間切替トグルに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      // トグルはデータがある期間のみ描画されるため、当週の支出をシードする
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries([
        _entry(id: 'w1', amount: 500, date: DateTime.now()),
      ]);
      await pumpScreen(tester, repository: repo);

      expect(find.bySemanticsIdentifier('summary_btn_toggle_weekly'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('summary_btn_toggle_monthly'),
          findsOneWidget);

      final weekly = tester.getSemantics(
        find.bySemanticsIdentifier('summary_btn_toggle_weekly'),
      );
      expect(weekly.label, contains('週間表示に切り替え'));
      handle.dispose();
    });
  });

  group('BudgetSettingsScreen アクセシビリティ', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BudgetSettingsScreen(
            repository: const BudgetRepository(),
          ),
        ),
      );
      await pumpFrames(tester, ticks: 6);
    }

    testWidgets('保存ボタンと入力欄に identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsIdentifier('budget_btn_save'), findsOneWidget);
      expect(find.bySemanticsIdentifier('budget_txt_amount'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('AppBar 導線と繰り越しスイッチに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsIdentifier('budget_btn_category_budget'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('budget_btn_category_ledger'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('budget_tgl_rollover'), findsOneWidget);

      final toggle = tester.getSemantics(
        find.bySemanticsIdentifier('budget_tgl_rollover'),
      );
      expect(toggle.hasFlag(SemanticsFlag.hasToggledState), isTrue);
      handle.dispose();
    });
  });

  group('TransactionHistoryPage アクセシビリティ', () {
    testWidgets('AppBar の3導線ボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: TransactionHistoryPage(
            controller: MockTransactionController(),
          ),
        ),
      );
      await pumpFrames(tester, ticks: 4);

      expect(find.bySemanticsIdentifier('history_btn_tag_manage'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('history_btn_tag_summary'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('history_btn_open_calendar'),
          findsOneWidget);
      handle.dispose();
    });
  });

  group('TransactionCalendarScreen アクセシビリティ', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      List<ExpenseEntry> entries = const [],
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TransactionCalendarScreen(
            entriesOverride: entries,
            clock: () => DateTime(2026, 9, 15, 12, 0),
            initialYear: 2026,
            initialMonth: 9,
          ),
        ),
      );
      await pumpFrames(tester, ticks: 4);
    }

    testWidgets('月移動ボタンに identifier が付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(find.bySemanticsIdentifier('calendar_btn_prev_month'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('calendar_btn_next_month'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('サマリーカード領域に identifier とラベルが付与される', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(
        tester,
        entries: [
          _entry(id: 'a', amount: 1200, date: DateTime(2026, 9, 5)),
          _entry(id: 'b', amount: 3400, date: DateTime(2026, 9, 20)),
        ],
      );

      final summary = find.bySemanticsIdentifier('calendar_sec_summary');
      expect(summary, findsOneWidget);
      final semantics = tester.getSemantics(summary);
      expect(semantics.label, contains('月間支出サマリー'));
      handle.dispose();
    });
  });
}

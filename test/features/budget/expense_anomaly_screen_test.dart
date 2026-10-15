import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/services/expense_repository_impl.dart';
import 'package:kozuchi/features/budget/domain/expense_anomaly_service.dart';
import 'package:kozuchi/features/budget/presentation/screens/expense_anomaly_screen.dart';
import 'package:kozuchi/features/trial_quest/presentation/screens/offering_input_screen.dart';

/// 固定「現在日時」
final DateTime _fixedNow = DateTime(2026, 10, 16, 12);

/// 食費の通常履歴（1,000円 × 5日）+ 異常候補（5,000円）
List<ExpenseEntry> _anomalousEntries() {
  final entries = <ExpenseEntry>[];
  for (var i = 1; i <= 5; i++) {
    entries.add(ExpenseEntry(
      id: 'hist-$i',
      amount: 1000,
      category: '食費',
      date: DateTime(2026, 10, i, 10),
    ));
  }
  entries.add(ExpenseEntry(
    id: 'candidate',
    amount: 5000,
    category: '食費',
    date: DateTime(2026, 10, 15, 10),
  ));
  return entries;
}

void main() {
  group('ExpenseAnomalyScreen', () {
    testWidgets('異常を含む履歴で行が表示され message/ratioLabel が出る', (tester) async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries(_anomalousEntries());

      await tester.pumpWidget(MaterialApp(
        home: ExpenseAnomalyScreen(
          repository: repo,
          now: () => _fixedNow,
        ),
      ));
      await tester.pumpAndSettle();

      // AppBar
      expect(find.text('支出の異常検知'), findsOneWidget);

      // 異常1件（5,000円・食費）の行
      final row = find.byKey(const Key('expenseAnomaly_row_candidate'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('¥5000')),
          findsOneWidget);
      // ratioLabel + message は1行に結合して表示される
      expect(
          find.descendant(
              of: row,
              matching: find.text('いつもの 5.0倍 ・ いつもより高い支出です')),
          findsOneWidget);
      // level ラベル（high）
      expect(find.descendant(of: row, matching: find.text('いつもより高い')),
          findsOneWidget);

      // 正常な履歴（1,000円）は異常判定されないので行が出ない
      expect(find.byKey(const Key('expenseAnomaly_row_hist-1')), findsNothing);

      // 空状態ではない
      expect(find.byKey(const Key('expenseAnomaly_empty')), findsNothing);
    });

    testWidgets('空履歴で empty キー表示', (tester) async {
      final repo = InMemoryExpenseRepository();

      await tester.pumpWidget(MaterialApp(
        home: ExpenseAnomalyScreen(
          repository: repo,
          now: () => _fixedNow,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expenseAnomaly_empty')), findsOneWidget);
      expect(find.text('普段どおりの支出です'), findsOneWidget);
      // 異常行はない
      expect(find.byKey(const Key('expenseAnomaly_row_candidate')),
          findsNothing);
    });

    testWidgets('サマリー件数が detectAll の結果件数と一致する', (tester) async {
      // 異常2件: 食費5,000円と娯楽6,000円
      final repo = InMemoryExpenseRepository();
      final entries = _anomalousEntries()
        ..add(ExpenseEntry(
          id: 'hist-e1',
          amount: 2000,
          category: '娯楽',
          date: DateTime(2026, 10, 1, 10),
        ))
        ..add(ExpenseEntry(
          id: 'hist-e2',
          amount: 2000,
          category: '娯楽',
          date: DateTime(2026, 10, 2, 10),
        ))
        ..add(ExpenseEntry(
          id: 'hist-e3',
          amount: 2000,
          category: '娯楽',
          date: DateTime(2026, 10, 3, 10),
        ))
        ..add(ExpenseEntry(
          id: 'entertainment-big',
          amount: 6000,
          category: '娯楽',
          date: DateTime(2026, 10, 14, 10),
        ));
      await repo.saveEntries(entries);

      final expected = const ExpenseAnomalyService().detectAll(entries);

      await tester.pumpWidget(MaterialApp(
        home: ExpenseAnomalyScreen(
          repository: repo,
          now: () => _fixedNow,
        ),
      ));
      await tester.pumpAndSettle();

      // 画面→service→表示の合成: 画面のサマリー件数と service の件数が一致
      final summaryText =
          find.descendant(of: find.byKey(const Key('expenseAnomaly_summary')),
              matching: find.textContaining('検知件数'));
      expect(summaryText, findsOneWidget);
      expect(
        tester.widget<Text>(summaryText).data,
        contains('検知件数 ${expected.length}件'),
      );
      // 行数も一致（row キーの数）
      final rowKeys = entries
          .where((e) => expected.any((a) => a.entry.id == e.id))
          .map((e) => find.byKey(Key('expenseAnomaly_row_${e.id}')));
      for (final key in rowKeys) {
        expect(key, findsOneWidget);
      }
      expect(expected.length, 2);
    });
  });

  group('OfferingInputScreen - 支出異常警告', () {
    final quest = TrialQuest(
      title: '誰かと食事を共にせよ',
      description: '友人や家族と食事をし、会計を済ませよ',
      suggestedOffering: 3000,
      advisor: Advisor.daikokuten,
    );
    final player = PlayerModel(hp: 100000, exp: 30);

    testWidgets('異常時にダイアログが出て「戻る」で pop しない', (tester) async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries(_anomalousEntries());

      OfferingResult? capturedResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<OfferingResult>(
                  MaterialPageRoute(
                    builder: (_) => OfferingInputScreen(
                      quest: quest,
                      player: player,
                      expenseRepository: repo,
                      now: () => _fixedNow,
                    ),
                  ),
                );
                capturedResult = result;
              },
              child: const Text('開く'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '3000'),
        '5000',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '友人との食事');

      // カテゴリを明示的に「食費」へ（自動分類に依存しない）
      await tester.ensureVisible(find.textContaining('食費'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('食費'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('支出を実行する'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('支出を実行する'));
      await tester.pumpAndSettle();

      // 警告ダイアログが表示される
      expect(find.text('いつもより高い支出です'), findsOneWidget);
      expect(find.textContaining('いつもの'), findsOneWidget);
      expect(find.textContaining('平均額'), findsOneWidget);

      // 「戻る」で記録中断（入力画面に留まる）
      await tester.tap(find.text('戻る'));
      await tester.pumpAndSettle();
      expect(find.text('支出の記録'), findsOneWidget);
      expect(capturedResult, isNull);
    });

    testWidgets('異常時に「このまま記録する」で pop する', (tester) async {
      final repo = InMemoryExpenseRepository();
      await repo.saveEntries(_anomalousEntries());

      OfferingResult? capturedResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<OfferingResult>(
                  MaterialPageRoute(
                    builder: (_) => OfferingInputScreen(
                      quest: quest,
                      player: player,
                      expenseRepository: repo,
                      now: () => _fixedNow,
                    ),
                  ),
                );
                capturedResult = result;
              },
              child: const Text('開く'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '3000'),
        '5000',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '友人との食事');

      // カテゴリを明示的に「食費」へ（自動分類に依存しない）
      await tester.ensureVisible(find.textContaining('食費'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('食費'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('支出を実行する'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('支出を実行する'));
      await tester.pumpAndSettle();

      expect(find.text('いつもより高い支出です'), findsOneWidget);

      await tester.tap(find.text('このまま記録する'));
      await tester.pumpAndSettle();

      // 通常どおり pop され結果が返る
      expect(find.text('支出の記録'), findsNothing);
      expect(capturedResult, isNotNull);
      expect(capturedResult!.amount, 5000);
    });

    testWidgets('expenseRepository null なら従来どおり即 pop する（回帰）', (tester) async {
      OfferingResult? capturedResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<OfferingResult>(
                  MaterialPageRoute(
                    builder: (_) => OfferingInputScreen(
                      quest: quest,
                      player: player,
                    ),
                  ),
                );
                capturedResult = result;
              },
              child: const Text('開く'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '3000'),
        '5000',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '友人との食事');

      await tester.ensureVisible(find.text('支出を実行する'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('支出を実行する'));
      await tester.pumpAndSettle();

      // ダイアログは出ず、即座に pop される
      expect(find.text('いつもより高い支出です'), findsNothing);
      expect(find.text('支出の記録'), findsNothing);
      expect(capturedResult, isNotNull);
      expect(capturedResult!.amount, 5000);
    });
  });
}

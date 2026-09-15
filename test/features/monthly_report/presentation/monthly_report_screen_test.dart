import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/monthly_report/presentation/screens/monthly_report_screen.dart';
import 'package:kozuchi/features/monthly_report/presentation/widgets/report_card_capture.dart';
import 'package:kozuchi/features/shared/presentation/kozuchi_app_keys.dart';

/// 期間で絞り込んで返すフェイクリポジトリ
class _FakeExpenseRepository implements ExpenseRepository {
  _FakeExpenseRepository(this.entries);

  final List<ExpenseEntry> entries;
  int calls = 0;
  final List<List<DateTime>> ranges = [];

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    calls++;
    ranges.add([
      DateTime(start.year, start.month, start.day),
      DateTime(end.year, end.month, end.day),
    ]);
    return entries.where((e) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
          !day.isAfter(DateTime(end.year, end.month, end.day));
    }).toList();
  }

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {}

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {}

  @override
  Future<int> getEntryCount() async => entries.length;

  @override
  Future<void> clearAll() async {}
}

/// 最初の呼び出しだけ失敗するリポジトリ
class _FlakyExpenseRepository implements ExpenseRepository {
  _FlakyExpenseRepository(this.entries);

  final List<ExpenseEntry> entries;
  int calls = 0;

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    calls++;
    if (calls == 1) {
      throw StateError('boom');
    }
    final day = DateTime(start.year, start.month, 1);
    final last = DateTime(end.year, end.month, end.day);
    return entries
        .where((e) => !e.date.isBefore(day) && !e.date.isAfter(last))
        .toList();
  }

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {}

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {}

  @override
  Future<int> getEntryCount() async => entries.length;

  @override
  Future<void> clearAll() async {}
}

class _RecordingCapture implements ReportCardCapture {
  _RecordingCapture(this.bytes);

  final Uint8List? bytes;
  int calls = 0;

  @override
  Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    calls++;
    return bytes;
  }
}

class _RecordingExporter implements ReportCardExporter {
  int calls = 0;
  Uint8List? png;
  String? fileName;
  String? text;

  @override
  Future<void> export({
    required Uint8List png,
    required String fileName,
    String? text,
  }) async {
    calls++;
    this.png = png;
    this.fileName = fileName;
    this.text = text;
  }
}

ExpenseEntry _entry({
  required String id,
  required int amount,
  required DateTime date,
  String category = '食費',
}) {
  return ExpenseEntry(
    id: id,
    amount: amount,
    category: category,
    date: date,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ExpenseRepository repository,
  ReportCardCapture? capture,
  ReportCardExporter? exporter,
  DateTime? initialMonth,
}) async {
  // カード全体が縦に収まるよう縦長ビューポートにする
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: MonthlyReportScreen(
        repository: repository,
        capture: capture,
        exporter: exporter,
        initialMonth: initialMonth ?? DateTime(2026, 9, 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final september = [
    _entry(id: '1', amount: 60000, date: DateTime(2026, 9, 3)),
    _entry(id: '2', amount: 40000, date: DateTime(2026, 9, 20), category: '交通費'),
  ];

  group('MonthlyReportScreen', () {
    testWidgets('読み込み中はインジケータを表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyReportScreen(
            repository: _FakeExpenseRepository(september),
            initialMonth: DateTime(2026, 9, 1),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('当月ラベルとレポートカードを表示する', (tester) async {
      await _pumpScreen(
        tester,
        repository: _FakeExpenseRepository(september),
      );
      expect(find.text('2026年9月'), findsOneWidget);
      expect(find.byKey(KozuchiAppKeys.monthlyReportCard), findsOneWidget);
      expect(find.text('2026年9月 家計レポート'), findsOneWidget);
      expect(find.text('100000円'), findsOneWidget);
    });

    testWidgets('リポジトリには当月と前月の2回問い合わせる', (tester) async {
      final repo = _FakeExpenseRepository(september);
      await _pumpScreen(tester, repository: repo);
      expect(repo.calls, 2);
      expect(repo.ranges[0], [DateTime(2026, 9, 1), DateTime(2026, 9, 30)]);
      expect(repo.ranges[1], [DateTime(2026, 8, 1), DateTime(2026, 8, 31)]);
    });

    testWidgets('データ無し月は記録なしの文言を表示する', (tester) async {
      await _pumpScreen(
        tester,
        repository: _FakeExpenseRepository(const []),
      );
      expect(find.text('この月の記録はありません'), findsOneWidget);
    });

    testWidgets('前月ボタンで前月を読み込む', (tester) async {
      final repo = _FakeExpenseRepository(september);
      await _pumpScreen(tester, repository: repo);

      await tester.tap(find.byKey(KozuchiAppKeys.monthlyReportPrevMonth));
      await tester.pumpAndSettle();

      expect(find.text('2026年8月'), findsOneWidget);
      expect(repo.calls, 4);
      expect(repo.ranges[2], [DateTime(2026, 8, 1), DateTime(2026, 8, 31)]);
    });

    testWidgets('当月では次月ボタンで翌月までは進める（それ以上は無効）', (tester) async {
      final repo = _FakeExpenseRepository(september);
      await _pumpScreen(
        tester,
        repository: repo,
        initialMonth: DateTime(2026, 9, 1),
      );
      final before = repo.calls;

      await tester.tap(find.byKey(KozuchiAppKeys.monthlyReportNextMonth));
      await tester.pumpAndSettle();

      expect(find.text('2026年10月'), findsOneWidget);
      expect(repo.calls, before + 2);
      final next = tester.widget<IconButton>(
        find.byKey(KozuchiAppKeys.monthlyReportNextMonth),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('未来月を初期表示すると次月ボタンが無効', (tester) async {
      await _pumpScreen(
        tester,
        repository: _FakeExpenseRepository(september),
        initialMonth: DateTime(2026, 12, 1),
      );
      final next = tester.widget<IconButton>(
        find.byKey(KozuchiAppKeys.monthlyReportNextMonth),
      );
      expect(next.onPressed, isNull);
      expect(find.text('2026年12月'), findsOneWidget);
    });

    testWidgets('過去月では次月ボタンが有効', (tester) async {
      await _pumpScreen(
        tester,
        repository: _FakeExpenseRepository(september),
        initialMonth: DateTime(2026, 8, 1),
      );
      final next = tester.widget<IconButton>(
        find.byKey(KozuchiAppKeys.monthlyReportNextMonth),
      );
      expect(next.onPressed, isNotNull);

      await tester.tap(find.byKey(KozuchiAppKeys.monthlyReportNextMonth));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月'), findsOneWidget);
    });

    testWidgets('共有ボタンで PNG とファイル名とテキストを渡す', (tester) async {
      final capture = _RecordingCapture(Uint8List.fromList([1, 2, 3, 4]));
      final exporter = _RecordingExporter();
      await _pumpScreen(
        tester,
        repository: _FakeExpenseRepository(september),
        capture: capture,
        exporter: exporter,
      );

      await tester.tap(find.byKey(KozuchiAppKeys.monthlyReportShareButton));
      await tester.pumpAndSettle();

      expect(capture.calls, 1);
      expect(exporter.calls, 1);
      expect(exporter.png, [1, 2, 3, 4]);
      expect(exporter.fileName, 'kozuchi_report_2026-09.png');
      expect(exporter.text, contains('2026年9月 家計レポート'));
    });

    testWidgets('キャプチャ失敗時はスナックバーを出し共有しない', (tester) async {
      final capture = _RecordingCapture(null);
      final exporter = _RecordingExporter();
      await _pumpScreen(
        tester,
        repository: _FakeExpenseRepository(september),
        capture: capture,
        exporter: exporter,
      );

      await tester.tap(find.byKey(KozuchiAppKeys.monthlyReportShareButton));
      await tester.pumpAndSettle();

      expect(find.text('画像の生成に失敗しました'), findsOneWidget);
      expect(exporter.calls, 0);
    });

    testWidgets('読み込み失敗時はエラーと再試行を表示し、再試行で回復する', (tester) async {
      final repo = _FlakyExpenseRepository(september);
      await _pumpScreen(tester, repository: repo);

      expect(find.text('読み込みに失敗しました'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);

      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.text('読み込みに失敗しました'), findsNothing);
      expect(find.byKey(KozuchiAppKeys.monthlyReportCard), findsOneWidget);
    });
  });
}

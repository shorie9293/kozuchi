import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_repository.dart';
import 'package:kozuchi/features/csv_export/data/csv_file_sharer.dart';
import 'package:kozuchi/features/csv_export/presentation/screens/csv_export_screen.dart';

/// 期間の受け取りを記録し、指定した明細を返す偽リポジトリ。
class _FakeExpenseRepository implements ExpenseRepository {
  _FakeExpenseRepository({this.entries = const [], this.throwOnGet = false});

  final List<ExpenseEntry> entries;
  final bool throwOnGet;
  DateTime? lastStart;
  DateTime? lastEnd;

  @override
  Future<List<ExpenseEntry>> getEntries({
    required DateTime start,
    required DateTime end,
  }) async {
    lastStart = start;
    lastEnd = end;
    if (throwOnGet) throw StateError('取得失敗');
    return entries;
  }

  @override
  Future<void> saveEntry(ExpenseEntry entry) async {}

  @override
  Future<void> saveEntries(List<ExpenseEntry> entries) async {}

  @override
  Future<int> getEntryCount() async => entries.length;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<ExpenseEntry?> getEntryById(String id) async => null;
}

/// 共有呼び出しを記録する偽共有器。
class _RecordingSharer implements CsvFileSharer {
  _RecordingSharer({this.throwOnShare = false});

  final bool throwOnShare;
  String? sharedCsv;
  String? sharedFileName;
  int callCount = 0;

  @override
  Future<void> share({required String csv, required String fileName}) async {
    callCount++;
    sharedCsv = csv;
    sharedFileName = fileName;
    if (throwOnShare) throw StateError('共有シートなし');
  }
}

ExpenseEntry _entry(String id, DateTime date, {String category = '食費'}) {
  return ExpenseEntry(
    id: id,
    amount: 1200,
    category: category,
    date: date,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ExpenseRepository repository,
  required CsvFileSharer sharer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CsvExportScreen(
        expenseRepository: repository,
        sharer: sharer,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('画面が描画され、旧メール/Drive導線は表示されない', (tester) async {
    await _pump(
      tester,
      repository: _FakeExpenseRepository(),
      sharer: _RecordingSharer(),
    );

    expect(find.byKey(const Key('csvExportScreen')), findsOneWidget);
    expect(find.byKey(const Key('csvExport_dateRangeCard')), findsOneWidget);
    expect(find.byKey(const Key('csvExport_exportButton')), findsOneWidget);
    expect(find.text('すべての期間'), findsOneWidget);

    // 旧 localhost:8080 API 依存の導線は UI から外れている
    expect(find.byKey(const Key('csvExport_emailField')), findsNothing);
    expect(find.byKey(const Key('csvExport_driveUploadButton')), findsNothing);
    expect(find.text('メールで共有'), findsNothing);
    expect(find.text('Google Driveで共有'), findsNothing);
  });

  testWidgets('書き出しタップで明細からCSVが生成され共有へ渡る', (tester) async {
    final repository = _FakeExpenseRepository(
      entries: [
        _entry('b', DateTime.utc(2026, 1, 6).toLocal()),
        _entry('a', DateTime.utc(2026, 1, 5).toLocal(), category: '交通費'),
        _entry('c', DateTime.utc(2026, 12, 31).toLocal()),
      ],
    );
    final sharer = _RecordingSharer();

    await _pump(tester, repository: repository, sharer: sharer);
    await tester.tap(find.byKey(const Key('csvExport_exportButton')));
    await tester.pumpAndSettle();

    // 画面の件数表示は「実際に書き出した行数」と一致する
    expect(find.byKey(const Key('csvExport_successCard')), findsOneWidget);
    expect(find.text('CSVを書き出しました（3件）'), findsOneWidget);

    expect(sharer.callCount, 1);
    expect(sharer.sharedFileName, endsWith('.csv'));
    final lines = sharer.sharedCsv!.split('\r\n').where((l) => l.isNotEmpty).toList();
    expect(lines.length, 4); // ヘッダ + 3件
    expect(lines.first, 'date,category,amount,note');
    expect(sharer.sharedCsv, contains('2026-01-05,交通費,1200,'));

    // 期間指定なしなら 2000-01-01 〜 現在で取得する
    expect(repository.lastStart, DateTime(2000, 1, 1));
    expect(repository.lastEnd, isNotNull);
  });

  testWidgets('0件でもヘッダのみのCSVを生成し、その旨を提示する', (tester) async {
    final sharer = _RecordingSharer();
    await _pump(
      tester,
      repository: _FakeExpenseRepository(),
      sharer: sharer,
    );

    await tester.tap(find.byKey(const Key('csvExport_exportButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('この期間の取引はありません'), findsOneWidget);
    expect(sharer.sharedCsv, 'date,category,amount,note\r\n');
  });

  testWidgets('共有が失敗してもCSV生成の完了は失われない', (tester) async {
    final sharer = _RecordingSharer(throwOnShare: true);
    await _pump(
      tester,
      repository: _FakeExpenseRepository(
        entries: [_entry('a', DateTime.utc(2026, 1, 5).toLocal())],
      ),
      sharer: sharer,
    );

    await tester.tap(find.byKey(const Key('csvExport_exportButton')));
    await tester.pumpAndSettle();

    expect(find.text('CSVを書き出しました（1件）'), findsOneWidget);
    expect(find.byKey(const Key('csvExport_shareErrorCard')), findsOneWidget);
    expect(sharer.callCount, 1);
  });

  testWidgets('明細の取得に失敗したらエラーカードを出し共有は呼ばない', (tester) async {
    final sharer = _RecordingSharer();
    await _pump(
      tester,
      repository: _FakeExpenseRepository(throwOnGet: true),
      sharer: sharer,
    );

    await tester.tap(find.byKey(const Key('csvExport_exportButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('csvExport_errorCard')), findsOneWidget);
    expect(sharer.callCount, 0);
  });
}

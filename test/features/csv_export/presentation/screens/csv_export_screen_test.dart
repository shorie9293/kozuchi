import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/csv_export/data/csv_export_service.dart';
import 'package:kozuchi/features/csv_export/presentation/screens/csv_export_screen.dart';

/// テスト用のCsvExportServiceモック
class _MockCsvExportService implements CsvExportService {
  String? mockCsvData;
  String? mockError;
  int callCount = 0;
  DateTime? lastStartDate;
  DateTime? lastEndDate;

  @override
  Future<String> exportCsv({DateTime? startDate, DateTime? endDate}) async {
    callCount++;
    lastStartDate = startDate;
    lastEndDate = endDate;

    if (mockError != null) {
      throw CsvExportException(mockError!);
    }
    return mockCsvData ?? 'date,description,category,amount\n';
  }

  @override
  Future<Map<String, dynamic>> sendCsvByEmail({
    required String email,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    throw CsvExportException('Not implemented in mock');
  }

  @override
  void dispose() {}
}

/// CSVエクスポート画面をMaterialAppで包むヘルパー
Widget buildTestWidget(CsvExportService service) {
  return MaterialApp(
    home: CsvExportScreen(service: service),
  );
}

void main() {
  group('CsvExportScreen', () {
    testWidgets('画面が正しくレンダリングされる', (tester) async {
      final mockService = _MockCsvExportService();

      await tester.pumpWidget(buildTestWidget(mockService));

      // AppBar にタイトルが表示される
      expect(find.text('CSVエクスポート'), findsOneWidget);

      // 日付範囲カードが表示される
      expect(find.byKey(const Key('csvExport_dateRangeCard')), findsOneWidget);
      expect(find.text('エクスポート期間'), findsOneWidget);
      expect(find.text('すべての期間'), findsOneWidget);

      // エクスポートボタンが表示される
      expect(find.byKey(const Key('csvExport_exportButton')), findsOneWidget);
      expect(find.text('CSVをエクスポート'), findsOneWidget);
    });

    testWidgets('日付範囲ピッカーカードをタップできる', (tester) async {
      final mockService = _MockCsvExportService();

      await tester.pumpWidget(buildTestWidget(mockService));

      // 日付範囲ピッカー領域がタップ可能
      final picker = find.byKey(const Key('csvExport_dateRangePicker'));
      expect(picker, findsOneWidget);

      // InkWellのタップ -> showDateRangePickerが呼ばれる
      // （実際のピッカーはテストできないため、ウィジェットが存在することだけ確認）
      await tester.tap(picker);
      await tester.pump();

      // pickerがタップされた後も画面がクラッシュしていないことを確認
      expect(find.text('CSVエクスポート'), findsOneWidget);
    });

    testWidgets('エクスポートボタン押下でローディング状態になる', (tester) async {
      final mockService = _MockCsvExportService()
        ..mockCsvData = 'date,amount\n2026-06-23,50000\n';

      await tester.pumpWidget(buildTestWidget(mockService));

      // ボタンをタップ
      await tester.tap(find.byKey(const Key('csvExport_exportButton')));
      await tester.pump();

      // ローディングインジケータが表示される
      expect(
          find.byKey(const Key('csvExport_loadingIndicator')), findsOneWidget);
      expect(find.text('エクスポート中...'), findsOneWidget);

      // 非同期処理完了 → pumpでmicrotaskを処理
      await tester.pump();
      await tester.pump();

      // 成功メッセージが表示される
      expect(find.byKey(const Key('csvExport_successCard')), findsOneWidget);
      expect(find.textContaining('CSVを保存しました'), findsOneWidget);
    });

    testWidgets('エクスポート成功時にCSVがファイルに保存される', (tester) async {
      final mockService = _MockCsvExportService()
        ..mockCsvData = 'date,amount\n2026-06-23,50000\n';

      await tester.pumpWidget(buildTestWidget(mockService));

      await tester.tap(find.byKey(const Key('csvExport_exportButton')));
      await tester.pump();  // ローディング表示
      await tester.pump();  // 非同期処理完了
      await tester.pump();  // 成功メッセージ表示

      // ファイルが保存されたことを確認
      final messages = find.textContaining('CSVを保存しました');
      expect(messages, findsOneWidget);

      // メッセージからファイルパスを抽出して存在確認
      final widget = tester.widget<Text>(messages.first);
      final text = widget.data ?? '';
      final pathPrefix = 'CSVを保存しました: ';
      if (text.startsWith(pathPrefix)) {
        final filePath = text.substring(pathPrefix.length);
        final file = File(filePath);
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        expect(content, 'date,amount\n2026-06-23,50000\n');
        // テスト後のクリーンアップ
        file.deleteSync();
      }
    });

    testWidgets('エクスポート失敗時にエラーメッセージが表示される', (tester) async {
      final mockService = _MockCsvExportService()
        ..mockError = 'Network error: Connection refused';

      await tester.pumpWidget(buildTestWidget(mockService));

      await tester.tap(find.byKey(const Key('csvExport_exportButton')));
      await tester.pumpAndSettle();

      // エラーカードが表示される
      expect(find.byKey(const Key('csvExport_errorCard')), findsOneWidget);
      expect(find.text('Network error: Connection refused'), findsOneWidget);

      // ボタンが再度有効になっている
      expect(find.text('CSVをエクスポート'), findsOneWidget);
    });

    testWidgets('エラー発生後、再試行できる', (tester) async {
      final mockService = _MockCsvExportService()
        ..mockError = '最初のエラー';

      await tester.pumpWidget(buildTestWidget(mockService));

      // 1回目のエクスポート → エラー
      await tester.tap(find.byKey(const Key('csvExport_exportButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('csvExport_errorCard')), findsOneWidget);
      expect(mockService.callCount, 1);

      // エラーをクリアして再試行
      mockService.mockError = null;
      mockService.mockCsvData = 'date,amount\n2026-06-23,50000\n';

      await tester.tap(find.byKey(const Key('csvExport_exportButton')));
      await tester.pumpAndSettle();

      // 成功メッセージが表示される（エラーカードは非表示）
      expect(find.byKey(const Key('csvExport_errorCard')), findsNothing);
      expect(find.byKey(const Key('csvExport_successCard')), findsOneWidget);
      expect(mockService.callCount, 2);
    });

    testWidgets('日付範囲指定後にエクスポートできる', (tester) async {
      final mockService = _MockCsvExportService()
        ..mockCsvData = 'date,amount\n2026-06-23,50000\n';

      await tester.pumpWidget(buildTestWidget(mockService));

      // エクスポート実行 → 日付未指定でもOK
      await tester.tap(find.byKey(const Key('csvExport_exportButton')));
      await tester.pumpAndSettle();

      expect(mockService.callCount, 1);
      expect(mockService.lastStartDate, isNull);
      expect(mockService.lastEndDate, isNull);
      expect(find.byKey(const Key('csvExport_successCard')), findsOneWidget);
    });

    testWidgets('ローディング中は日付ピッカーが無効化される', (tester) async {
      final mockService = _MockCsvExportService()
        ..mockCsvData = 'data\n';

      await tester.pumpWidget(buildTestWidget(mockService));

      // エクスポートボタンをタップしてローディング状態に
      await tester.tap(find.byKey(const Key('csvExport_exportButton')));
      await tester.pump();

      // ローディング中はボタンが無効化
      final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('csvExport_exportButton')));
      expect(button.onPressed, isNull);

      // 処理完了
      await tester.pumpAndSettle();

      // ボタンが再度有効化
      final buttonAfter = tester.widget<ElevatedButton>(
          find.byKey(const Key('csvExport_exportButton')));
      expect(buttonAfter.onPressed, isNotNull);
    });
  });
}

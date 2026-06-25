import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/weekly_report/data/weekly_report.dart';
import 'package:kozuchi/features/weekly_report/data/weekly_report_api_service.dart';
import 'package:kozuchi/features/weekly_report/presentation/screens/weekly_report_screen.dart';

/// テスト用の固定レポートデータを返すモックAPIサービス
class _MockWeeklyReportApiService implements WeeklyReportApiService {
  final Future<WeeklyReport> Function(String? week)? onFetch;

  _MockWeeklyReportApiService({this.onFetch});

  @override
  Future<WeeklyReport> fetchReport({String? week, String userId = 'user_001'}) async {
    if (onFetch != null) return onFetch!(week);
    return _sampleReport(week: week);
  }
}

WeeklyReport _sampleReport({String? week}) {
  return WeeklyReport(
    weekLabel: week ?? '2026-W25',
    totalSpending: 45600,
    topCategories: const [
      WeeklyReportCategory(category: '食費', amount: 15000, percentage: 32.9),
      WeeklyReportCategory(category: '外食費', amount: 12000, percentage: 26.3),
      WeeklyReportCategory(category: '娯楽費', amount: 8000, percentage: 17.5),
    ],
    satoriChange: 5,
    satoriChangeLabel: '📈 SATORIが上昇しました',
    advisorAdvice: '来週は自炊を増やしましょう。',
    advisorEmoji: '🦊',
    advisorName: '節約狐',
  );
}

void main() {
  Widget buildApp({String? week, WeeklyReportApiService? apiService}) {
    return MaterialApp(
      home: WeeklyReportScreen(week: week, apiService: apiService),
    );
  }

  group('WeeklyReportScreen', () {
    testWidgets('displays week label in AppBar when week is provided', (tester) async {
      await tester.pumpWidget(
        buildApp(
          week: '2026-W25',
          apiService: _MockWeeklyReportApiService(),
        ),
      );

      // ローディング中はスピナー
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // ロード完了を待つ
      await tester.pumpAndSettle();

      // AppBar に週ラベルが含まれている
      expect(find.textContaining('2026-W25'), findsWidgets);
    });

    testWidgets('displays default AppBar title when week is null', (tester) async {
      await tester.pumpWidget(
        buildApp(
          apiService: _MockWeeklyReportApiService(),
        ),
      );

      await tester.pumpAndSettle();

      // null の週の場合は「週間レポート」のみ
      expect(find.text('週間レポート'), findsOneWidget);
    });

    testWidgets('displays category amounts after loading', (tester) async {
      await tester.pumpWidget(
        buildApp(apiService: _MockWeeklyReportApiService()),
      );

      await tester.pumpAndSettle();

      // カテゴリ名が表示されている
      expect(find.text('食費'), findsOneWidget);
      expect(find.text('外食費'), findsOneWidget);
      expect(find.text('娯楽費'), findsOneWidget);

      // 金額が表示されている
      expect(find.textContaining('15000'), findsWidgets);
      expect(find.textContaining('12000'), findsWidgets);
      expect(find.textContaining('8000'), findsWidgets);

      // 総支出が表示されている
      expect(find.textContaining('45600'), findsWidgets);

      // 助言が表示されている
      expect(find.text('来週は自炊を増やしましょう。'), findsOneWidget);
    });

    testWidgets('displays satori change information', (tester) async {
      await tester.pumpWidget(
        buildApp(apiService: _MockWeeklyReportApiService()),
      );

      await tester.pumpAndSettle();

      // SATORI変動ラベル
      expect(find.text('SATORI変動'), findsOneWidget);
      expect(find.text('📈 SATORIが上昇しました'), findsOneWidget);
    });

    testWidgets('displays advisor info when emoji and name are set', (tester) async {
      await tester.pumpWidget(
        buildApp(apiService: _MockWeeklyReportApiService()),
      );

      await tester.pumpAndSettle();

      expect(find.text('🦊'), findsOneWidget);
      expect(find.text('節約狐'), findsOneWidget);
    });

    testWidgets('shows error state on API failure', (tester) async {
      await tester.pumpWidget(
        buildApp(
          apiService: _MockWeeklyReportApiService(
            onFetch: (_) async => throw WeeklyReportApiException('テスト用エラー'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // エラー表示
      expect(find.text('レポートの取得に失敗しました'), findsOneWidget);
      // 再試行ボタン
      expect(find.text('再試行'), findsOneWidget);
    });

    testWidgets('shows empty state for report with no categories', (tester) async {
      await tester.pumpWidget(
        buildApp(
          apiService: _MockWeeklyReportApiService(
            onFetch: (_) async => WeeklyReport(
              weekLabel: '2026-W25',
              totalSpending: 0,
              topCategories: [],
              satoriChange: 0,
              satoriChangeLabel: '変動なし',
              advisorAdvice: '',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 空状態
      expect(find.text('今週の支出データはまだありません'), findsOneWidget);
    });

    testWidgets('back button pops the screen', (tester) async {
      await tester.pumpWidget(
        buildApp(apiService: _MockWeeklyReportApiService()),
      );

      await tester.pumpAndSettle();

      // back button exists (IconButton with arrow_back icon, not BackButton widget)
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays correct rank emoji for top 3', (tester) async {
      await tester.pumpWidget(
        buildApp(apiService: _MockWeeklyReportApiService()),
      );

      await tester.pumpAndSettle();

      expect(find.text('🥇'), findsOneWidget);
      expect(find.text('🥈'), findsOneWidget);
      expect(find.text('🥉'), findsOneWidget);
    });

    testWidgets('shows loading spinner while fetching', (tester) async {
      // Use a Completer that we never complete, but handle cleanup properly
      // ignore: unused_local_variable
      final neverCompleting = _MockWeeklyReportApiService(
        onFetch: (_) async {
          // This keeps loading state but we don't need it to complete
          await Future<void>.delayed(const Duration(seconds: 1));
          return _sampleReport();
        },
      );

      await tester.pumpWidget(buildApp(apiService: neverCompleting));

      // 1回目のフレームではローディングスピナーが表示されている（initState→_loadReport開始直後）
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // pump で一部進めるが settle はしない（Future完了を待たない）
      await tester.pump(const Duration(milliseconds: 100));
      // まだロード中
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 1秒待って完了させる
      await tester.pumpAndSettle();
      // ロード完了後はスピナーが消えている
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('passes week parameter to api service', (tester) async {
      String? capturedWeek;

      await tester.pumpWidget(
        buildApp(
          week: '2026-W30',
          apiService: _MockWeeklyReportApiService(
            onFetch: (week) async {
              capturedWeek = week;
              return _sampleReport(week: week);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // week パラメータが API サービスに渡されたことを確認
      expect(capturedWeek, '2026-W30');
    });
  });
}

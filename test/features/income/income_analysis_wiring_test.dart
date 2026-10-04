import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/income/domain/services/income_analysis_service.dart';
import 'package:kozuchi/features/income/domain/services/income_entry_recording_service.dart';
import 'package:kozuchi/features/income/domain/services/income_repository.dart';
import 'package:kozuchi/features/income/presentation/screens/income_analysis_screen.dart';
import 'package:kozuchi/features/income/presentation/widgets/income_analysis_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 親探針（合成の不変条件）:
  /// 「記録フロー → 永続化 → 別インスタンスでの復元 → 集計」
  /// が一連のパイプラインとして壊れないことを撃つ。

  testWidgets('記録→保存→別インスタンス復元→画面集計が合成される', (tester) async {
    // 記録フロー（時刻を進めてID重複を避ける）
    final repo = InMemoryIncomeRepository();
    var micros = 0;
    final service = IncomeEntryRecordingService(
      repository: repo,
      clock: () => DateTime(2026, 10, 4).add(Duration(microseconds: micros++)),
    );

    await service.record(amount: 30000, source: '給与', note: '十月');
    await service.record(amount: 10000, source: '副業');
    await service.record(amount: 10000, source: '給与 '); // 正規化で給与に合流

    // 別インスタンス（再起動相当）での復元
    final restored = await repo.getAllEntries();
    expect(restored.length, 3);

    // 復元データから画面を構築して集計を検証
    await tester.pumpWidget(
      MaterialApp(
        home: IncomeAnalysisScreen(entries: restored),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 給与 40000・副業 10000・合計 50000
    expect(find.text('合計 ¥50000・最多 給与'), findsOneWidget);
    expect(find.text('収入源 2 件・記録 3 件'), findsOneWidget);
    expect(
      tester.widget<Text>(
        find.byKey(IncomeAnalysisAppKeys.sourceAmount('給与')),
      ).data,
      '¥40,000',
    );
  });

  test('Noop リポジトリでも記録フローが例外なく完遂される', () async {
    final service = IncomeEntryRecordingService(
      repository: const NoopIncomeRepository(),
    );
    final saved = await service.record(amount: 100, source: '贈与');
    expect(saved, isNotNull);
    expect(await service.repository.getAllEntries(), isEmpty);
  });

  test('SharedPreferences の永続経由で集計に到達する（再起動相当の復元）', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPreferencesIncomeRepository(prefs);
    var micros = 0;
    final service = IncomeEntryRecordingService(
      repository: repo,
      clock: () => DateTime(2026, 10, 4).add(Duration(microseconds: micros++)),
    );

    await service.record(amount: 5000, source: 'ボーナス');
    await service.record(amount: 2000, source: 'ボーナス');

    // 新インスタンス（再起動相当）
    final restored = await SharedPreferencesIncomeRepository(prefs)
        .getAllEntries();
    expect(restored.length, 2);
    final summaries = IncomeAnalysisService.aggregateBySource(restored);
    expect(summaries.single.source, 'ボーナス');
    expect(summaries.single.amount, 7000);
    expect(summaries.single.count, 2);
  });
}

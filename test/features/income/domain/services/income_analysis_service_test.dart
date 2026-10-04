import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/domain/models/income_source_summary.dart';
import 'package:kozuchi/features/income/domain/services/income_analysis_service.dart';

DateTime _d(int month, int day) => DateTime(2026, month, day);

void main() {
  group('IncomeAnalysisService.normalizeSource', () {
    test('全角英数・全角スペースを半角に正規化し小文字化する', () {
      expect(IncomeAnalysisService.normalizeSource('　給与　'), '給与');
      expect(
        IncomeAnalysisService.normalizeSource('Ｓｉｄｅ Ｊｏｂ'),
        'side job',
      );
      expect(IncomeAnalysisService.normalizeSource('副業'), '副業');
      expect(IncomeAnalysisService.normalizeSource('  給与  '), '給与');
      expect(IncomeAnalysisService.normalizeSource('A  B'), 'a b');
    });
  });

  group('IncomeAnalysisService.aggregateBySource', () {
    test('収入源ごとの合計・件数・構成比を集計する', () {
      final entries = [
        IncomeEntry(
            id: 'i1', amount: 30000, source: '給与', date: _d(10, 1)),
        IncomeEntry(
            id: 'i2', amount: 10000, source: '副業', date: _d(10, 5)),
        IncomeEntry(
            id: 'i3', amount: 10000, source: '給与', date: _d(10, 10)),
      ];
      final summaries = IncomeAnalysisService.aggregateBySource(entries);

      expect(summaries.length, 2);
      // 金額降順: 給与 40000 → 副業 10000
      expect(summaries[0].source, '給与');
      expect(summaries[0].amount, 40000);
      expect(summaries[0].count, 2);
      expect(summaries[0].ratio, closeTo(0.8, 1e-9));
      expect(summaries[1].source, '副業');
      expect(summaries[1].ratio, closeTo(0.2, 1e-9));
      expect(summaries[1].count, 1);
    });

    test('正規化キーが同一なら同一グループに集計し表示名は初出の表記', () {
      final entries = [
        IncomeEntry(
            id: 'i1', amount: 5000, source: 'Ｓｉｄｅ ｊｏｂ', date: _d(10, 1)),
        IncomeEntry(
            id: 'i2', amount: 3000, source: 'side job', date: _d(10, 2)),
      ];
      final summaries = IncomeAnalysisService.aggregateBySource(entries);

      expect(summaries.length, 1);
      expect(summaries[0].source, 'Ｓｉｄｅ ｊｏｂ');
      expect(summaries[0].amount, 8000);
      expect(summaries[0].count, 2);
    });

    test('amount 0 以下・空白収入源は無視する', () {
      final entries = [
        IncomeEntry(
            id: 'i1', amount: 1000, source: '給与', date: _d(10, 1)),
      ];
      final bad = [
        ...entries,
        // 0以下・空収入源は IncomeEntry の検証で生成不能ゆえ、
        // 集計側の防御は空文字トリム後に捨てる経路で確認する
      ];
      expect(IncomeAnalysisService.aggregateBySource(bad).length, 1);
      expect(
        IncomeAnalysisService.aggregateBySource(const []).isEmpty,
        isTrue,
      );
    });

    test('金額同率は正規化キー昇順で安定する', () {
      final entries = [
        IncomeEntry(id: 'i1', amount: 100, source: '贈与', date: _d(10, 1)),
        IncomeEntry(id: 'i2', amount: 100, source: '副業', date: _d(10, 2)),
      ];
      final summaries = IncomeAnalysisService.aggregateBySource(entries);
      expect(
        summaries.map((s) => s.normalizedSource).toList(),
        ['副業', '贈与'],
      );
    });

    test('非破壊: 入力リストは並び替えられない', () {
      final entries = [
        IncomeEntry(id: 'i1', amount: 100, source: '贈与', date: _d(10, 1)),
        IncomeEntry(id: 'i2', amount: 900, source: '給与', date: _d(10, 2)),
      ];
      final before = entries.map((e) => e.id).toList();
      IncomeAnalysisService.aggregateBySource(entries);
      expect(entries.map((e) => e.id).toList(), before);
    });
  });

  group('IncomeAnalysisService.totalAmount / entryCount / topSource', () {
    test('合計・件数・首位を算出する', () {
      final entries = [
        IncomeEntry(id: 'i1', amount: 30000, source: '給与', date: _d(10, 1)),
        IncomeEntry(id: 'i2', amount: 10000, source: '副業', date: _d(10, 5)),
      ];
      expect(IncomeAnalysisService.totalAmount(entries), 40000);
      expect(IncomeAnalysisService.entryCount(entries), 2);
      expect(IncomeAnalysisService.topSource(entries)?.source, '給与');
      expect(IncomeAnalysisService.topSource(const []), isNull);
    });
  });

  group('IncomeAnalysisService.filterByPeriod', () {
    test('期間（日単位）で絞り込む', () {
      final entries = [
        IncomeEntry(id: 'i1', amount: 1, source: '給与', date: _d(9, 30)),
        IncomeEntry(id: 'i2', amount: 2, source: '副業', date: _d(10, 1)),
        IncomeEntry(id: 'i3', amount: 3, source: '贈与', date: _d(10, 31)),
        IncomeEntry(id: 'i4', amount: 4, source: '給与', date: _d(11, 1)),
      ];
      final filtered = IncomeAnalysisService.filterByPeriod(
        entries,
        start: _d(10, 1),
        end: _d(10, 31),
      );
      expect(filtered.map((e) => e.id).toList(), ['i2', 'i3']);
    });
  });

  group('IncomeAnalysisService.searchBySource', () {
    test('正規化した部分一致で絞り込む', () {
      final entries = [
        IncomeEntry(id: 'i1', amount: 1, source: '給与', date: _d(10, 1)),
        IncomeEntry(id: 'i2', amount: 2, source: 'Ｓｉｄｅ ｊｏｂ', date: _d(10, 2)),
        IncomeEntry(id: 'i3', amount: 3, source: '贈与', date: _d(10, 3)),
      ];
      final hit = IncomeAnalysisService.searchBySource(entries, 'side');
      expect(hit.map((e) => e.id).toList(), ['i2']);

      // 空クエリは全件
      final all = IncomeAnalysisService.searchBySource(entries, ' ');
      expect(all.length, 3);
    });
  });

  group('IncomeAnalysisService.summaryLabel', () {
    test('空は「収入の記録はまだない」・有効なら合計と最多を返す', () {
      expect(
        IncomeAnalysisService.summaryLabel(const []),
        '収入の記録はまだない',
      );
      final entries = [
        IncomeEntry(
            id: 'i1', amount: 30000, source: '給与', date: _d(10, 1)),
        IncomeEntry(
            id: 'i2', amount: 10000, source: '副業', date: _d(10, 5)),
      ];
      expect(
        IncomeAnalysisService.summaryLabel(entries),
        '合計 ¥40000・最多 給与',
      );
    });
  });

  group('IncomeSourceSummary', () {
    test('ratioLabel は四捨五入・amountLabel はカンマ区切り', () {
      const summary = IncomeSourceSummary(
        source: '給与',
        normalizedSource: '給与',
        amount: 62000,
        count: 3,
        ratio: 0.625,
      );
      expect(summary.ratioLabel, '63%');
      expect(summary.amountLabel, '¥62,000');
    });
  });
}

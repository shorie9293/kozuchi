import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/budget/domain/expense_anomaly.dart';
import 'package:kozuchi/features/budget/domain/expense_anomaly_service.dart';

ExpenseEntry _e(
  String id,
  int amount,
  String category, {
  DateTime? date,
}) =>
    ExpenseEntry(
      id: id,
      amount: amount,
      category: category,
      date: date ?? DateTime(2026, 10, 1),
    );

/// 履歴: 同カテゴリ3件（各1000）→ average 1000
List<ExpenseEntry> _history3(String category) => [
      _e('h1', 1000, category),
      _e('h2', 1000, category),
      _e('h3', 1000, category),
    ];

void main() {
  const service = ExpenseAnomalyService();

  group('detect', () {
    test('ちょうど elevatedRatio（2.0倍）は異常判定（elevated）', () {
      final a = service.detect(
        candidate: _e('c', 2000, '食費'),
        history: _history3('食費'),
      );
      expect(a, isNotNull);
      expect(a!.level, AnomalyLevel.elevated);
      expect(a.ratio, closeTo(2.0, 1e-9));
      expect(a.average, 1000.0);
      expect(a.sampleCount, 3);
      expect(a.category, '食費');
      expect(a.amount, 2000);
      expect(a.message, 'いつもより高い支出です');
    });

    test('ちょうど highRatio（3.0倍）は high', () {
      final a = service.detect(
        candidate: _e('c', 3000, '食費'),
        history: _history3('食費'),
      );
      expect(a!.level, AnomalyLevel.high);
    });

    test('しきい値ちょうど手前（1.9999倍相当）は null', () {
      // 履歴平均を大きくして ratio < 2.0 にする
      final a = service.detect(
        candidate: _e('c', 2000, '食費'),
        history: [
          _e('h1', 1001, '食費'),
          _e('h2', 1001, '食費'),
          _e('h3', 1000, '食費'),
        ],
      );
      expect(a, isNull);
    });

    test('サンプル数ちょうど minSamples（3件）は判定可能', () {
      expect(
        service.detect(
          candidate: _e('c', 2000, '食費'),
          history: _history3('食費'),
          minSamples: 3,
        ),
        isNotNull,
      );
    });

    test('サンプル不足（2件）は null', () {
      final a = service.detect(
        candidate: _e('c', 2000, '食費'),
        history: [_e('h1', 1000, '食費'), _e('h2', 1000, '食費')],
      );
      expect(a, isNull);
    });

    test('別カテゴリの履歴は無視される', () {
      final a = service.detect(
        candidate: _e('c', 2000, '食費'),
        history: [
          _e('h1', 1000, '交通費'),
          _e('h2', 1000, '娯楽'),
          _e('h3', 1000, '食費'), // 同カテゴリは1件のみ → 不足
        ],
      );
      expect(a, isNull);
    });

    test('自分自身（同一id）は履歴から除外される（平均が自分の額で汚染されない）', () {
      // 自分(10000)を含めると平均 3250 → ratio 3.07 で high になるが、
      // 除外されれば平均 1000 → ratio 10.0 で high。件数3で成立することを確認。
      final history = [
        _e('c', 10000, '食費'), // 自分自身と同一id
        _e('h1', 1000, '食費'),
        _e('h2', 1000, '食費'),
      ];
      final a = service.detect(candidate: _e('c', 10000, '食費'), history: history);
      // 履歴は実質2件 → minSamples 未満で null
      expect(a, isNull);
    });

    test('同一id除外により平均が汚染されない（サンプル4件構成）', () {
      final history = [
        _e('c', 10000, '食費'),
        _e('h1', 1000, '食費'),
        _e('h2', 1000, '食費'),
        _e('h3', 1000, '食費'),
      ];
      final a = service.detect(candidate: _e('c', 10000, '食費'), history: history);
      expect(a, isNotNull);
      expect(a!.average, 1000.0);
      expect(a.sampleCount, 3);
      expect(a.ratio, closeTo(10.0, 1e-9));
    });

    test('category空（または空白のみ）は「未分類」に寄せられる', () {
      final history = [
        _e('h1', 1000, '未分類'),
        _e('h2', 1000, '未分類'),
        _e('h3', 1000, '未分類'),
      ];
      final a1 = service.detect(candidate: _e('c', 2000, ''), history: history);
      final a2 = service.detect(candidate: _e('c', 2000, '  '), history: history);
      expect(a1!.category, '未分類');
      expect(a2!.category, '未分類');
    });

    test('candidate.category の前後空白は trim されて一致判定される', () {
      final history = _history3('食費');
      final a = service.detect(
        candidate: _e('c', 2000, ' 食費 '),
        history: history,
      );
      expect(a!.category, '食費');
    });

    test('空履歴は null', () {
      expect(
        service.detect(candidate: _e('c', 2000, '食費'), history: const []),
        isNull,
      );
    });
  });

  group('detectAll', () {
    test('異常のみ抽出・date降順ソート', () {
      final entries = [
        _e('a', 3000, '食費', date: DateTime(2026, 10, 1)), // 異常
        _e('b', 1000, '食費', date: DateTime(2026, 10, 2)),
        _e('c', 1000, '食費', date: DateTime(2026, 10, 3)),
        _e('b2', 1000, '食費', date: DateTime(2026, 10, 9)),
        _e('d', 5000, '交通費', date: DateTime(2026, 10, 4)), // 異常
        _e('e', 1000, '交通費', date: DateTime(2026, 10, 5)),
        _e('f', 1000, '交通費', date: DateTime(2026, 10, 6)),
        _e('e2', 1000, '交通費', date: DateTime(2026, 10, 8)),
        _e('g', 1000, '娯楽', date: DateTime(2026, 10, 7)), // 正常
      ];
      final results = service.detectAll(entries);
      expect(results.map((r) => r.entry.id).toList(), ['d', 'a']);
      expect(results.every((r) => r.message == 'いつもより高い支出です'), isTrue);
    });

    test('同時刻は entry.id 昇順', () {
      final sameDate = DateTime(2026, 10, 10);
      final entries = [
        _e('z', 3000, '食費', date: sameDate),
        _e('a', 3000, '食費', date: sameDate),
        _e('m', 1000, '食費', date: sameDate),
        _e('n', 1000, '食費', date: sameDate),
        _e('o', 1000, '食費', date: sameDate),
        _e('p', 1000, '食費', date: sameDate),
      ];
      final results = service.detectAll(entries);
      expect(results.map((r) => r.entry.id).toList(), ['a', 'z']);
    });

    test('全員が同じ額なら異常なし', () {
      final entries = [
        for (var i = 0; i < 5; i++) _e('x$i', 1000, '食費'),
      ];
      expect(service.detectAll(entries), isEmpty);
    });

    test('空エントリ群は空リスト', () {
      expect(service.detectAll(const []), isEmpty);
    });
  });

  group('categoryAverages', () {
    test('カテゴリ別平均（amount>0のみ、空カテゴリは未分類）', () {
      final entries = [
        _e('a', 1000, '食費'),
        _e('b', 3000, '食費'),
        _e('c', 500, '交通費'),
        _e('d', 700, ''),
        _e('e', 900, '  '),
        _e('f', 1000, '娯楽'),
      ];
      final result = service.categoryAverages(entries);
      expect(result['食費'], closeTo(2000.0, 1e-9));
      expect(result['交通費'], closeTo(500.0, 1e-9));
      expect(result['未分類'], closeTo(800.0, 1e-9));
      expect(result['娯楽'], closeTo(1000.0, 1e-9));
      expect(result.length, 4);
    });

    test('空入力は空マップ', () {
      expect(service.categoryAverages(const []), isEmpty);
    });
  });

  group('ExpenseAnomaly 不変条件', () {
    ExpenseEntry entry() => _e('c', 2000, '食費');

    test('amount <= 0 は ArgumentError', () {
      expect(
        () => ExpenseAnomaly(
          entry: entry(),
          category: '食費',
          amount: 0,
          average: 1000,
          ratio: 2.0,
          sampleCount: 3,
          level: AnomalyLevel.elevated,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExpenseAnomaly(
          entry: entry(),
          category: '食費',
          amount: -1,
          average: 1000,
          ratio: 2.0,
          sampleCount: 3,
          level: AnomalyLevel.elevated,
        ),
        throwsArgumentError,
      );
    });

    test('average <= 0 は ArgumentError', () {
      expect(
        () => ExpenseAnomaly(
          entry: entry(),
          category: '食費',
          amount: 2000,
          average: 0,
          ratio: 2.0,
          sampleCount: 3,
          level: AnomalyLevel.elevated,
        ),
        throwsArgumentError,
      );
    });

    test('ratio < 1.0 は ArgumentError', () {
      expect(
        () => ExpenseAnomaly(
          entry: entry(),
          category: '食費',
          amount: 2000,
          average: 1000,
          ratio: 0.99,
          sampleCount: 3,
          level: AnomalyLevel.elevated,
        ),
        throwsArgumentError,
      );
    });

    test('ratioLabel は小数第1位', () {
      final a = ExpenseAnomaly(
        entry: entry(),
        category: '食費',
        amount: 2400,
        average: 1000,
        ratio: 2.4,
        sampleCount: 3,
        level: AnomalyLevel.elevated,
      );
      expect(a.ratioLabel, 'いつもの 2.4倍');
    });

    test('AnomalyLevel ラベル', () {
      expect(AnomalyLevel.elevated.label, 'やや高い');
      expect(AnomalyLevel.high.label, 'いつもより高い');
    });
  });

  group('サービス定数', () {
    test('既定しきい値', () {
      expect(ExpenseAnomalyService.defaultElevatedRatio, 2.0);
      expect(ExpenseAnomalyService.defaultHighRatio, 3.0);
      expect(ExpenseAnomalyService.defaultMinSamples, 3);
    });
  });
}
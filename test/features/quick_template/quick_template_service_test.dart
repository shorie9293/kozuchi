import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';
import 'package:kozuchi/features/quick_template/domain/quick_template_service.dart';

ExpenseTemplate _tpl(
  String id, {
  int amount = 100,
  String purpose = '昼食',
  String category = '食費',
  int useCount = 0,
  DateTime? lastUsedAt,
  DateTime? createdAt,
}) {
  return ExpenseTemplate(
    id: id,
    amount: amount,
    purpose: purpose,
    category: category,
    useCount: useCount,
    lastUsedAt: lastUsedAt,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

ExpenseEntry _entry(
  String id, {
  required int amount,
  required String purpose,
  required String category,
  required DateTime date,
}) {
  return ExpenseEntry(
    id: id,
    amount: amount,
    category: category,
    date: date,
    note: purpose,
  );
}

void main() {
  group('sortByUsage', () {
    test('useCount 降順で並ぶ', () {
      final list = [
        _tpl('a', useCount: 1),
        _tpl('b', useCount: 3),
        _tpl('c', useCount: 2),
      ];
      final sorted = QuickTemplateService.sortByUsage(list);
      expect(sorted.map((t) => t.id).toList(), ['b', 'c', 'a']);
    });

    test('useCount 同数は lastUsedAt 降順、null は末尾', () {
      final list = [
        _tpl('a', useCount: 1, lastUsedAt: DateTime(2026, 9, 1)),
        _tpl('b', useCount: 1),
        _tpl('c', useCount: 1, lastUsedAt: DateTime(2026, 9, 3)),
        _tpl('d', useCount: 1, lastUsedAt: DateTime(2026, 9, 2)),
      ];
      final sorted = QuickTemplateService.sortByUsage(list);
      expect(sorted.map((t) => t.id).toList(), ['c', 'd', 'a', 'b']);
    });

    test('全て同条件なら createdAt 昇順 → id 昇順', () {
      final list = [
        _tpl('b2', createdAt: DateTime(2026, 1, 2)),
        _tpl('a2', createdAt: DateTime(2026, 1, 2)),
        _tpl('a1', createdAt: DateTime(2026, 1, 1)),
      ];
      final sorted = QuickTemplateService.sortByUsage(list);
      expect(sorted.map((t) => t.id).toList(), ['a1', 'a2', 'b2']);
    });

    test('元のリストを破壊しない', () {
      final list = [_tpl('a', useCount: 1), _tpl('b', useCount: 2)];
      QuickTemplateService.sortByUsage(list);
      expect(list.map((t) => t.id).toList(), ['a', 'b']);
    });
  });

  group('upsert', () {
    test('同一 id は置換される', () {
      final list = [_tpl('a', amount: 100)];
      final updated = QuickTemplateService.upsert(
        list,
        _tpl('a', amount: 200),
      );
      expect(updated.length, 1);
      expect(updated.first.amount, 200);
    });

    test('未知の id は追加される', () {
      final list = [_tpl('a')];
      final updated = QuickTemplateService.upsert(list, _tpl('b'));
      expect(updated.length, 2);
    });

    test('amount<=0 は ArgumentError', () {
      expect(
        () => QuickTemplateService.upsert([], _tpl('a', amount: 0)),
        throwsArgumentError,
      );
    });

    test('空 purpose / 空 category は ArgumentError', () {
      expect(
        () => QuickTemplateService.upsert([], _tpl('a', purpose: ' ')),
        throwsArgumentError,
      );
      expect(
        () => QuickTemplateService.upsert([], _tpl('a', category: '')),
        throwsArgumentError,
      );
    });
  });

  group('remove', () {
    test('指定 id のみ取り除く', () {
      final list = [_tpl('a'), _tpl('b')];
      final removed = QuickTemplateService.remove(list, 'a');
      expect(removed.map((t) => t.id).toList(), ['b']);
    });

    test('存在しない id は何も起こらない', () {
      final list = [_tpl('a')];
      final removed = QuickTemplateService.remove(list, 'zzz');
      expect(removed.length, 1);
    });
  });

  group('applyTemplate', () {
    test('useCount+1・lastUsedAt=now の新しいテンプレートを返す', () {
      final t = _tpl('a', useCount: 2);
      final now = DateTime(2026, 9, 17, 12);
      final used = QuickTemplateService.applyTemplate(t, now);
      expect(used.useCount, 3);
      expect(used.lastUsedAt, now);
      expect(used.id, 'a');
      expect(identical(used, t), isFalse);
    });
  });

  group('frequentTemplates', () {
    test('使用回数順の先頭 limit 件を返す', () {
      final list = [
        for (var i = 0; i < 8; i++) _tpl('t$i', useCount: i),
      ];
      final result = QuickTemplateService.frequentTemplates(list, limit: 5);
      expect(result.length, 5);
      expect(result.first.useCount, 7);
    });

    test('limit<=0 は ArgumentError', () {
      expect(
        () => QuickTemplateService.frequentTemplates([], limit: 0),
        throwsArgumentError,
      );
    });
  });

  group('draftOf', () {
    test('amount/purpose/category を持つ軽量値に変換する', () {
      final t = _tpl('a', amount: 500, purpose: '昼食', category: '食費');
      final draft = QuickTemplateService.draftOf(t);
      expect(draft.amount, 500);
      expect(draft.purpose, '昼食');
      expect(draft.category, '食費');
    });
  });

  group('suggestFromEntries', () {
    test('用途+カテゴリ単位で頻度集計し、出現回数降順で返す', () {
      final entries = [
        _entry('e1', amount: 100, purpose: '昼食', category: '食費',
            date: DateTime(2026, 9, 1)),
        _entry('e2', amount: 120, purpose: '昼食', category: '食費',
            date: DateTime(2026, 9, 2)),
        _entry('e3', amount: 500, purpose: 'コーヒー', category: '娯楽',
            date: DateTime(2026, 9, 3)),
      ];
      final result = QuickTemplateService.suggestFromEntries(entries);
      expect(result.length, 2);
      expect(result.first.purpose, '昼食');
      expect(result.first.useCount, 2);
    });

    test('金額の代表値は最頻額、同数なら最新の額', () {
      final entries = [
        _entry('e1', amount: 100, purpose: '昼食', category: '食費',
            date: DateTime(2026, 9, 1)),
        _entry('e2', amount: 200, purpose: '昼食', category: '食費',
            date: DateTime(2026, 9, 2)),
        _entry('e3', amount: 100, purpose: '昼食', category: '食費',
            date: DateTime(2026, 9, 3)),
        _entry('e4', amount: 200, purpose: '昼食', category: '食費',
            date: DateTime(2026, 9, 4)),
      ];
      final result = QuickTemplateService.suggestFromEntries(entries);
      // 100 と 200 が同数 → 最新の 200
      expect(result.first.amount, 200);
    });

    test('出現回数同数は中央値降順（偶数個は下位側）', () {
      final entries = [
        _entry('e1', amount: 100, purpose: '昼食', category: '食費',
            date: DateTime(2026, 9, 1)),
        _entry('e2', amount: 200, purpose: '昼食', category: '食費',
            date: DateTime(2026, 9, 2)),
        _entry('e3', amount: 1000, purpose: '夕食', category: '食費',
            date: DateTime(2026, 9, 3)),
        _entry('e4', amount: 2000, purpose: '夕食', category: '食費',
            date: DateTime(2026, 9, 4)),
      ];
      final result = QuickTemplateService.suggestFromEntries(entries);
      // 昼食の中央値(下位側)=100、夕食=1000 → 夕食が先
      expect(result.first.purpose, '夕食');
    });

    test('limit<=0 は ArgumentError', () {
      expect(
        () => QuickTemplateService.suggestFromEntries([], limit: 0),
        throwsArgumentError,
      );
    });

    test('空履歴からは空候補', () {
      expect(QuickTemplateService.suggestFromEntries([]), isEmpty);
    });
  });
}

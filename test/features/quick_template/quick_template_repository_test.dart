import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/quick_template/data/quick_template_repository.dart';
import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';

ExpenseTemplate _tpl(
  String id, {
  int amount = 100,
  String purpose = '昼食',
  String category = '食費',
  int useCount = 0,
}) {
  return ExpenseTemplate(
    id: id,
    amount: amount,
    purpose: purpose,
    category: category,
    useCount: useCount,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesQuickTemplateRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('未保存時は空リスト', () async {
      final repo = const SharedPreferencesQuickTemplateRepository();
      expect(await repo.loadTemplates(), isEmpty);
    });

    test('保存→読み出しの往復', () async {
      final repo = const SharedPreferencesQuickTemplateRepository();
      final templates = [
        _tpl('a', amount: 500, useCount: 2),
        _tpl('b', amount: 120),
      ];
      await repo.saveTemplates(templates);
      final loaded = await repo.loadTemplates();
      expect(loaded, templates);
    });

    test('破損JSONは空リスト', () async {
      SharedPreferences.setMockInitialValues({
        'kozuchi_quick_templates': 'not-json{{',
      });
      final repo = const SharedPreferencesQuickTemplateRepository();
      expect(await repo.loadTemplates(), isEmpty);
    });

    test('破損要素（amount<=0 など）は読み飛ばされる', () async {
      SharedPreferences.setMockInitialValues({
        'kozuchi_quick_templates': '''
[
  {"id": "bad1", "amount": 0, "purpose": "x", "category": "食費", "useCount": 0, "createdAt": "2026-01-01T00:00:00.000"},
  {"id": "good1", "amount": 300, "purpose": "昼食", "category": "食費", "useCount": 1, "createdAt": "2026-01-01T00:00:00.000"},
  {"id": "bad2", "amount": 100, "purpose": "", "category": "食費", "useCount": 0, "createdAt": "2026-01-01T00:00:00.000"},
  "garbage"
]
''',
      });
      final repo = const SharedPreferencesQuickTemplateRepository();
      final loaded = await repo.loadTemplates();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'good1');
    });
  });

  group('InMemoryQuickTemplateRepository', () {
    test('保存→読み出しの往復', () async {
      final repo = InMemoryQuickTemplateRepository();
      expect(await repo.loadTemplates(), isEmpty);
      await repo.saveTemplates([_tpl('a')]);
      final loaded = await repo.loadTemplates();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'a');
    });

    test('保存内容の上書き', () async {
      final repo = InMemoryQuickTemplateRepository();
      await repo.saveTemplates([_tpl('a')]);
      await repo.saveTemplates([_tpl('b'), _tpl('c')]);
      final loaded = await repo.loadTemplates();
      expect(loaded.map((t) => t.id).toList(), ['b', 'c']);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = TagRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TagRepository タグ定義', () {
    test('未保存時は空リスト', () async {
      expect(await repository.loadTags(), isEmpty);
    });

    test('作成したタグを読み出せる', () async {
      await repository.createTag('旅行', id: 't1');
      await repository.createTag('サブスク', id: 't2');

      final tags = await repository.loadTags();
      expect(tags.map((t) => t.name).toList(), ['旅行', 'サブスク']);
      expect(tags.first.id, 't1');
    });

    test('名前の前後空白は除去される', () async {
      await repository.createTag('  食費  ', id: 't1');
      final tags = await repository.loadTags();
      expect(tags.single.name, '食費');
    });

    test('空白のみの名前は ArgumentError', () async {
      expect(
        () => repository.createTag('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('改名できる', () async {
      await repository.createTag('旅行', id: 't1');
      final updated = await repository.renameTag('t1', '国内旅行');

      expect(updated.single.name, '国内旅行');
      expect((await repository.loadTags()).single.name, '国内旅行');
    });

    test('存在しないIDの改名は何も変えない', () async {
      await repository.createTag('旅行', id: 't1');
      final updated = await repository.renameTag('nope', 'X');
      expect(updated.single.name, '旅行');
    });

    test('削除できる', () async {
      await repository.createTag('旅行', id: 't1');
      await repository.createTag('サブスク', id: 't2');

      final updated = await repository.deleteTag('t1');

      expect(updated.map((t) => t.id).toList(), ['t2']);
      expect((await repository.loadTags()).length, 1);
    });

    test('削除時は紐付けからも当該タグを取り除く', () async {
      await repository.createTag('旅行', id: 't1');
      await repository.assignTags('key1', const ['t1', 't2']);
      await repository.assignTags('key2', const ['t1']);

      await repository.deleteTag('t1');

      final assignments = await repository.loadAssignments();
      expect(assignments['key1'], ['t2']);
      expect(assignments.containsKey('key2'), isFalse);
    });

    test('破損JSONは空リストとして扱う', () async {
      SharedPreferences.setMockInitialValues({
        TagRepository.tagsKey: '{not json',
      });
      expect(await repository.loadTags(), isEmpty);
    });

    test('保存形式は tag の JSON 配列', () async {
      await repository.createTag('旅行', id: 't1', colorValue: 0xFF00FF00);
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString(TagRepository.tagsKey)!);

      expect(decoded, isA<List<dynamic>>());
      expect((decoded as List).single, {
        'id': 't1',
        'name': '旅行',
        'color': 0xFF00FF00,
      });
    });
  });

  group('TagRepository 紐付け', () {
    test('未保存時は空マップ', () async {
      expect(await repository.loadAssignments(), isEmpty);
    });

    test('紐付けを保存して読み出せる', () async {
      await repository.assignTags('key1', const ['t1', 't2']);
      expect(await repository.tagsFor('key1'), ['t1', 't2']);
      expect(await repository.tagsFor('key2'), isEmpty);
    });

    test('重複したタグIDは正規化される', () async {
      await repository.assignTags('key1', const ['t1', 't1', 't2']);
      expect(await repository.tagsFor('key1'), ['t1', 't2']);
    });

    test('空リストで紐付けが解除される', () async {
      await repository.assignTags('key1', const ['t1']);
      await repository.assignTags('key1', const []);

      expect(await repository.tagsFor('key1'), isEmpty);
      expect((await repository.loadAssignments()).containsKey('key1'), isFalse);
    });

    test('破損JSONは空マップとして扱う', () async {
      SharedPreferences.setMockInitialValues({
        TagRepository.assignmentsKey: 'broken',
      });
      expect(await repository.loadAssignments(), isEmpty);
    });

    test('空文字のタグIDは保存しない', () async {
      await repository.assignTags('key1', const ['', 't1', '']);
      expect(await repository.tagsFor('key1'), ['t1']);
    });
  });

  group('統合', () {
    test('作成したタグ定義と紐付けを集計に渡せる', () async {
      await repository.createTag('旅行', id: 't1');
      await repository.assignTags('key1', const ['t1']);

      final tags = await repository.loadTags();
      final assignments = await repository.loadAssignments();

      expect(tags.single, const ExpenseTag(id: 't1', name: '旅行'));
      expect(assignments['key1'], ['t1']);
    });
  });
}

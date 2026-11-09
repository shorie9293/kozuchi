import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = TagRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TagRepository.removeKeys', () {
    test('該当キーの紐付けだけが消える', () async {
      await repository.assignTags('key1', const ['t1']);
      await repository.assignTags('key2', const ['t2']);

      final changed = await repository.removeKeys(['key1']);

      expect(changed, isTrue);
      expect(await repository.tagsFor('key1'), isEmpty);
      expect(await repository.tagsFor('key2'), ['t2']);
    });

    test('存在しないキーなら false で、他の紐付けは保持される', () async {
      await repository.assignTags('key1', const ['t1']);

      final changed = await repository.removeKeys(['nope']);

      expect(changed, isFalse);
      expect(await repository.tagsFor('key1'), ['t1']);
    });

    test('空文字キーは無視する（保存もしない）', () async {
      await repository.assignTags('key1', const ['t1']);

      expect(await repository.removeKeys(const ['', '']), isFalse);
      expect(await repository.tagsFor('key1'), ['t1']);
    });

    test('空の紐付けマップに対しては false', () async {
      expect(await repository.removeKeys(['key1']), isFalse);
    });
  });

  group('TagRepository.pruneOrphans', () {
    test('既知が空なら 0 件かつ紐付けを全保持する（安全弁）', () async {
      await repository.assignTags('key1', const ['t1']);
      await repository.assignTags('key2', const ['t2']);

      final removed = await repository.pruneOrphans(const []);

      expect(removed, 0);
      final assignments = await repository.loadAssignments();
      expect(assignments.keys.toList()..sort(), ['key1', 'key2']);
    });

    test('孤児のみ削除し、件数を返す', () async {
      await repository.assignTags('keep', const ['t1']);
      await repository.assignTags('gone1', const ['t2']);
      await repository.assignTags('gone2', const ['t3']);

      final removed = await repository.pruneOrphans(const ['keep']);

      expect(removed, 2);
      expect(await repository.tagsFor('keep'), ['t1']);
      expect(await repository.tagsFor('gone1'), isEmpty);
      expect(await repository.tagsFor('gone2'), isEmpty);
      expect((await repository.loadAssignments()).length, 1);
    });

    test('孤児が無ければ 0 件', () async {
      await repository.assignTags('keep', const ['t1']);

      expect(await repository.pruneOrphans(const ['keep']), 0);
      expect(await repository.tagsFor('keep'), ['t1']);
    });

    test('紐付けが空なら 0 件', () async {
      expect(await repository.pruneOrphans(const ['keep']), 0);
    });
  });
}

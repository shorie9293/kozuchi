import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/theme/reduce_motion_repository.dart';
import 'package:kozuchi/core/theme/reduce_motion_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReduceMotionRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('未保存時は load が null を返す', () async {
      const repo = ReduceMotionRepository();
      expect(await repo.load(), isNull);
    });

    test('save→load の往復で設定を復元する（on / off）', () async {
      const repo = ReduceMotionRepository();
      await repo.save(ReduceMotionSetting.on);
      expect(await repo.load(), ReduceMotionSetting.on);

      await repo.save(ReduceMotionSetting.off);
      expect(await repo.load(), ReduceMotionSetting.off);

      await repo.save(ReduceMotionSetting.system);
      expect(await repo.load(), ReduceMotionSetting.system);
    });

    test('保存キーは kozuchi_reduce_motion（storageKey文字列）', () async {
      const repo = ReduceMotionRepository();
      await repo.save(ReduceMotionSetting.on);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kozuchi_reduce_motion'), 'on');
    });

    test('不正値（未知文字列）は null に読み飛ばす', () async {
      SharedPreferences.setMockInitialValues(
          {'kozuchi_reduce_motion': 'broken'});
      const repo = ReduceMotionRepository();
      expect(await repo.load(), isNull);
    });

    test('InMemoryReduceMotionRepository: saved と saveCount を公開する',
        () async {
      final repo = InMemoryReduceMotionRepository();
      expect(await repo.load(), isNull);
      expect(repo.saveCount, 0);

      await repo.save(ReduceMotionSetting.on);
      expect(await repo.load(), ReduceMotionSetting.on);
      expect(repo.saved, ReduceMotionSetting.on);
      expect(repo.saveCount, 1);

      await repo.save(ReduceMotionSetting.off);
      expect(repo.saved, ReduceMotionSetting.off);
      expect(repo.saveCount, 2);
    });
  });
}

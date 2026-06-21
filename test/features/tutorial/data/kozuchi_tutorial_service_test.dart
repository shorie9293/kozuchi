import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/tutorial/data/kozuchi_tutorial_service.dart';

void main() {
  group('KozuchiTutorialService', () {
    setUp(() {
      // SharedPreferences のモック初期値をレベルMAXに設定
      SharedPreferences.setMockInitialValues({});
    });

    test('isFirstLaunch: 初回起動時（completed未設定）は true を返す', () async {
      final result = await KozuchiTutorialService.isFirstLaunch();
      expect(result, isTrue);
    });

    test('isFirstLaunch: markCompleted 呼出し後は false を返す', () async {
      // 事前準備: markCompleted を呼ぶ
      await KozuchiTutorialService.markCompleted();

      final result = await KozuchiTutorialService.isFirstLaunch();
      expect(result, isFalse);
    });

    test('markCompleted: 呼出し後 isFirstLaunch が false になる', () async {
      // 呼出し前は true
      expect(await KozuchiTutorialService.isFirstLaunch(), isTrue);

      await KozuchiTutorialService.markCompleted();

      // 呼出し後は false
      expect(await KozuchiTutorialService.isFirstLaunch(), isFalse);
    });
  });
}

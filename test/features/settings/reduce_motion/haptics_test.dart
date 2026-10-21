import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hapticTap は同期呼び出しで例外を投げない（await禁止の禍津回避）', () {
    // await するとテスト環境ではチャネル未解決で永久に完了しないため、
    // 戻り値は void（fire-and-forget）であることを型でも担保する。
    expect(() => hapticTap(), returnsNormally);
  });

  test('hapticTap を連続呼び出しても例外を投げない', () {
    expect(() {
      hapticTap();
      hapticTap();
      hapticTap();
    }, returnsNormally);
  });
}

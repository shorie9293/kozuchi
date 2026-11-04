import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/input/unsaved_changes.dart';

void main() {
  group('UnsavedChangesGuard.isDirty', () {
    test('同一文字列は未変更', () {
      expect(UnsavedChangesGuard.isDirty('昼食', '昼食'), isFalse);
    });

    test('末尾の空白・改行だけの差は未変更', () {
      expect(UnsavedChangesGuard.isDirty('昼食', ' 昼食\n'), isFalse);
    });

    test('本文が変われば変更あり', () {
      expect(UnsavedChangesGuard.isDirty('', '書きかけのメモ'), isTrue);
    });

    test('空白のみの入力は未変更（誤操作で確認を出さない）', () {
      expect(UnsavedChangesGuard.isDirty('', '   '), isFalse);
    });
  });

  group('UnsavedChangesGuard.isAnyDirty', () {
    test('全項目が同一なら未変更', () {
      expect(
        UnsavedChangesGuard.isAnyDirty(
          {'amount': '500', 'note': '昼食'},
          {'amount': '500', 'note': '昼食'},
        ),
        isFalse,
      );
    });

    test('いずれか1項目でも変われば変更あり', () {
      expect(
        UnsavedChangesGuard.isAnyDirty(
          {'amount': '500', 'note': '昼食'},
          {'amount': '600', 'note': '昼食'},
        ),
        isTrue,
      );
    });

    test('片方にしか無いキーは変更あり', () {
      expect(
        UnsavedChangesGuard.isAnyDirty({'amount': '500'}, {'amount': '500', 'note': 'x'}),
        isTrue,
      );
    });
  });

  test('確認文言は破棄を明示する', () {
    expect(UnsavedChangesGuard.confirmMessage(), contains('破棄'));
  });
}

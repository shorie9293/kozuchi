import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/undo/domain/undo_buffer.dart';

/// 取引削除のUndo（元に戻す）を支える単一スロットバッファの試練。
///
/// 仕様:
/// - [UndoBuffer.push] は直前の保持値を返す（初回は null）
/// - [UndoBuffer.take] は一度だけ値を返し、以降は null（二重復元防止）
void main() {
  group('UndoBuffer', () {
    test('初期状態は空で canUndo は false、peek/take は null', () {
      final buffer = UndoBuffer<String>();

      expect(buffer.canUndo, isFalse);
      expect(buffer.peek(), isNull);
      expect(buffer.take(), isNull);
    });

    test('push すると canUndo が true になり peek で同じ値が返る', () {
      final buffer = UndoBuffer<String>();

      final previous = buffer.push('削除された取引');

      expect(previous, isNull, reason: '初回 push の直前値は無い');
      expect(buffer.canUndo, isTrue);
      expect(buffer.peek(), '削除された取引');
      expect(buffer.canUndo, isTrue, reason: 'peek は取り出さない');
    });

    test('take は一度だけ値を返し、二度目以降は null', () {
      final buffer = UndoBuffer<String>()..push('a');

      expect(buffer.take(), 'a');
      expect(buffer.take(), isNull);
      expect(buffer.take(), isNull);
      expect(buffer.canUndo, isFalse);
      expect(buffer.peek(), isNull);
    });

    test('take 後は再度 push できる', () {
      final buffer = UndoBuffer<String>()..push('a');

      expect(buffer.take(), 'a');
      buffer.push('b');

      expect(buffer.peek(), 'b');
      expect(buffer.take(), 'b');
    });

    test('push を重ねると最新のみ保持し、直前値を返す', () {
      final buffer = UndoBuffer<String>();

      expect(buffer.push('old'), isNull);
      expect(buffer.push('new'), 'old');

      expect(buffer.peek(), 'new');
      expect(buffer.take(), 'new');
    });

    test('clear で空になり、保持値は破棄される', () {
      final buffer = UndoBuffer<int>()..push(1);

      buffer.clear();

      expect(buffer.canUndo, isFalse);
      expect(buffer.peek(), isNull);
      expect(buffer.take(), isNull);
    });

    test('clear は空バッファでも安全（冪等）', () {
      final buffer = UndoBuffer<int>();

      buffer.clear();
      buffer.clear();

      expect(buffer.canUndo, isFalse);
    });

    test('ジェネリック: 任意の型を保持できる', () {
      final buffer = UndoBuffer<Map<String, int>>()..push({'amount': -3000});

      expect(buffer.take(), {'amount': -3000});
      expect(buffer.take(), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_bootstrap.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_policy.dart';

/// 起動時フック（投げっぱなし）が例外を外へ漏らさないことを検める試練。
void main() {
  late InMemoryAutoBackupStore store;

  setUp(() {
    store = InMemoryAutoBackupStore(now: () => DateTime(2026, 10, 29, 8, 0));
  });

  test('起動時に1度だけ自動バックアップを書き出す', () async {
    scheduleAutoBackup(
      buildJson: () async => '{"a":1}',
      store: store,
    );

    await Future<void>.delayed(Duration.zero);

    // 実時計で走るため暦日（JST/UTC）に依存しない形で検める。
    expect(store.files.length, 1);
    final fileName = store.files.keys.single;
    expect(AutoBackupPolicy.isAutoBackupFile(fileName), isTrue);
    expect(store.files[fileName], '{"a":1}');
  });

  test('採取の例外は呼び出し元へ伝播しない', () async {
    expect(
      () => scheduleAutoBackup(
        buildJson: () async => throw StateError('採取失敗'),
        store: store,
      ),
      returnsNormally,
    );

    await Future<void>.delayed(Duration.zero);

    expect(store.files, isEmpty);
  });

  test('同期例外でも伝播しない（debugPrint のみ）', () async {
    expect(
      () => scheduleAutoBackup(
        buildJson: () => throw StateError('同期失敗'),
        store: store,
      ),
      returnsNormally,
    );

    await Future<void>.delayed(Duration.zero);
  });
}

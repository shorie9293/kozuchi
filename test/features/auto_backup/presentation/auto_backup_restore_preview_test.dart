import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_keys.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';

class _FakeRestorer implements AutoBackupRestorer {
  final List<String> calls = <String>[];

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    calls.add(fileName);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

const String _fileName = 'auto_backup_20261003.json';

String _backupJson(Map<String, Object?> entries) => jsonEncode({
      'schemaVersion': 1,
      'exportedAt': '2026-10-03T00:00:00.000Z',
      'entries': entries,
    });

void main() {
  late InMemoryAutoBackupStore store;

  setUp(() {
    store = InMemoryAutoBackupStore(now: () => DateTime(2026, 10, 3, 6, 0));
  });

  Future<void> openDialog(
    WidgetTester tester, {
    BackupRepository? backupRepository,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AutoBackupScreen(
          store: store,
          restorer: _FakeRestorer(),
          backupRepository: backupRepository,
          now: () => DateTime(2026, 10, 3, 6, 0),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(AutoBackupAppKeys.restoreButton(_fileName)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('backupRepository 未指定ならプレビューを出さない（後方互換）', (tester) async {
    await store.write(_fileName, _backupJson({'kozuchi_a': 1}));

    await openDialog(tester);

    expect(find.byKey(AutoBackupAppKeys.confirmDialog), findsOneWidget);
    expect(
      find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
      findsOneWidget,
    );
    expect(find.byKey(AutoBackupAppKeys.restorePreview), findsNothing);
  });

  testWidgets('backupRepository 指定時は内訳プレビューを出す（既存文言は不変）', (tester) async {
    await store.write(
      _fileName,
      _backupJson({'kozuchi_keep': 'same', 'kozuchi_changed': 'new'}),
    );
    final repository = InMemoryBackupRepository({
      'kozuchi_keep': 'same',
      'kozuchi_changed': 'old',
    });

    await openDialog(tester, backupRepository: repository);

    expect(
      find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
      findsOneWidget,
    );
    final preview = tester.widget<Text>(
      find.byKey(AutoBackupAppKeys.restorePreview),
    );
    expect(preview.data, contains('新規 0件'));
    expect(preview.data, contains('上書き 1件'));
    expect(preview.data, contains('変更なし 1件'));
  });

  testWidgets('破損JSONならプレビューを出さず従来文言のみ', (tester) async {
    // Map としては解釈できる（=復元ボタンは出る）が Bundle としては不正
    await store.write(_fileName, '{"ok":1}');
    final repository = InMemoryBackupRepository({'kozuchi_a': 1});

    await openDialog(tester, backupRepository: repository);

    expect(tester.takeException(), isNull);
    expect(find.byKey(AutoBackupAppKeys.confirmDialog), findsOneWidget);
    expect(
      find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
      findsOneWidget,
    );
    expect(find.byKey(AutoBackupAppKeys.restorePreview), findsNothing);
  });
}

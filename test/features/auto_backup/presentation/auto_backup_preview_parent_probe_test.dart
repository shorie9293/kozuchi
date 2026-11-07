import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_keys.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';

/// 親探針（自動バックアップ側の狭幅・破損JSON）。
class _FakeRestorer implements AutoBackupRestorer {
  final List<String> calls = <String>[];
  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    calls.add(fileName);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

const String _fileName = 'auto_backup_20261108.json';

String _json(Map<String, Object?> entries) => jsonEncode({
      'schemaVersion': 1,
      'exportedAt': '2026-11-08T00:00:00.000Z',
      'entries': entries,
    });

void main() {
  Future<void> open(
    WidgetTester tester, {
    required AutoBackupStore store,
    BackupRepository? repository,
    required _FakeRestorer restorer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AutoBackupScreen(
          store: store,
          restorer: restorer,
          backupRepository: repository,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(AutoBackupAppKeys.restoreButton(_fileName)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('探針7: 自動バックアップ側も狭幅(360x640)で溢れない', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = InMemoryAutoBackupStore(
      now: () => DateTime(2026, 11, 8, 6, 0),
    );
    final keys = <String, Object?>{
      for (var i = 0; i < 8; i++)
        'kozuchi_very_long_shared_preferences_key_name_$i': 'new',
    };
    await store.write(_fileName, _json(keys));
    final repository = InMemoryBackupRepository({
      for (var i = 0; i < 8; i++)
        'kozuchi_very_long_shared_preferences_key_name_$i': 'old',
    });

    await open(
      tester,
      store: store,
      repository: repository,
      restorer: _FakeRestorer(),
    );

    expect(find.byKey(AutoBackupAppKeys.confirmDialog), findsOneWidget);
    expect(find.byKey(AutoBackupAppKeys.restorePreview), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('探針8: 自動バックアップ側の破損JSONではプレビューを出さず再試行も落ちない', (tester) async {
    final store = InMemoryAutoBackupStore(
      now: () => DateTime(2026, 11, 8, 6, 0),
    );
    // entries 欠落（canRestore は通るが parse が失敗する型）
    await store.write(_fileName, '{"schemaVersion":1}');
    final restorer = _FakeRestorer();

    await open(
      tester,
      store: store,
      repository: InMemoryBackupRepository({'kozuchi_a': 'old'}),
      restorer: restorer,
    );

    expect(find.byKey(AutoBackupAppKeys.confirmDialog), findsOneWidget);
    expect(find.byKey(AutoBackupAppKeys.restorePreview), findsNothing);
    expect(
      find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

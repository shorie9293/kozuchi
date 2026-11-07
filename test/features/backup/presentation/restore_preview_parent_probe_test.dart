import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/backup/data/backup_file_io.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';
import 'package:kozuchi/features/backup/presentation/backup_keys.dart';
import 'package:kozuchi/features/backup/presentation/backup_screen.dart';

/// 親探針（眷属が撃たない合成の不変条件を親が独立に撃つ）。
class _FakeExporter implements BackupExporter {
  @override
  Future<void> export({required String json, required String fileName}) async {}
}

class _FakeImporter implements BackupImporter {
  String? json;
  @override
  Future<String?> pickJson() async => json;
}

String _bundleJson(Map<String, Object?> entries) => jsonEncode({
      'schemaVersion': 1,
      'exportedAt': '2026-11-08T00:00:00.000Z',
      'entries': entries,
    });

void main() {
  Widget build(BackupRepository repository, _FakeImporter importer) =>
      MaterialApp(
        home: BackupScreen(
          repository: repository,
          exporter: _FakeExporter(),
          importer: importer,
        ),
      );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(BackupAppKeys.restoreButton));
    await tester.pumpAndSettle();
  }

  testWidgets('探針1: プレビューの3数が実際の復元結果(RestoreResult)と一致する', (tester) async {
    final repository = InMemoryBackupRepository({
      'kozuchi_old': 'old',
      'kozuchi_same': 'same',
      'kozuchi_untouched': 'keep',
    });
    final importer = _FakeImporter()
      ..json = _bundleJson({
        'kozuchi_old': 'new',
        'kozuchi_same': 'same',
        'kozuchi_fresh': 'x',
      });

    await tester.pumpWidget(build(repository, importer));
    await tester.pumpAndSettle();
    await openDialog(tester);

    // プレビュー: 新規1 / 上書き1 / 変更なし1
    expect(
      find.text('新規 1件 / 上書き 1件 / 変更なし 1件'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(BackupAppKeys.confirmRestoreButton));
    await tester.pumpAndSettle();

    // 実結果は「新規/更新/変更なし」表記で同数でなければならない
    expect(find.text('新規 1件 / 更新 1件 / 変更なし 1件'), findsOneWidget);
    expect(repository.store['kozuchi_old'], 'new');
    expect(repository.store['kozuchi_fresh'], 'x');
    // バンドル外の既存キーは消えない
    expect(repository.store['kozuchi_untouched'], 'keep');
  });

  testWidgets('探針2: 新規のみなら「既存データは上書きされません」と明示する', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_old': 'old'});
    final importer = _FakeImporter()
      ..json = _bundleJson({'kozuchi_a': '1', 'kozuchi_b': '2'});

    await tester.pumpWidget(build(repository, importer));
    await tester.pumpAndSettle();
    await openDialog(tester);

    expect(find.byKey(BackupAppKeys.restorePreviewSummary), findsOneWidget);
    expect(find.text('新規 2件 / 上書き 0件 / 変更なし 0件'), findsOneWidget);
    expect(
      find.text('既存データは上書きされません（新規データのみ追加されます）'),
      findsOneWidget,
    );
    // 上書き抜粋は出さない
    expect(find.byKey(BackupAppKeys.restorePreviewSamples), findsNothing);
  });

  testWidgets('探針3: 上書きが6件以上なら抜粋5件＋「ほか N件」に畳まれる', (tester) async {
    final existing = <String, Object?>{
      for (var i = 0; i < 8; i++) 'kozuchi_k$i': 'old',
    };
    final repository = InMemoryBackupRepository(Map.of(existing));
    final importer = _FakeImporter()
      ..json = _bundleJson({
        for (var i = 0; i < 8; i++) 'kozuchi_k$i': 'new',
      });

    await tester.pumpWidget(build(repository, importer));
    await tester.pumpAndSettle();
    await openDialog(tester);

    final samples = tester.widget<Text>(
      find.byKey(BackupAppKeys.restorePreviewSamples),
    );
    final body = samples.data!;
    expect(body.split('\n・').length - 1, 5); // 抜粋は5件まで
    expect(body.contains('ほか 3件'), isTrue);
    expect(body.contains('kozuchi_k0'), isTrue);
    expect(body.contains('kozuchi_k7'), isFalse); // 6件目以降は畳まれる
  });

  testWidgets('探針4: 狭幅(360x640)でもダイアログが溢れない', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemoryBackupRepository({
      for (var i = 0; i < 8; i++)
        'kozuchi_very_long_shared_preferences_key_name_$i': 'old',
    });
    final importer = _FakeImporter()
      ..json = _bundleJson({
        for (var i = 0; i < 8; i++)
          'kozuchi_very_long_shared_preferences_key_name_$i': 'new',
      });

    await tester.pumpWidget(build(repository, importer));
    await tester.pumpAndSettle();
    await openDialog(tester);

    expect(find.byKey(BackupAppKeys.confirmRestoreDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('探針5: キャンセル時はプレビューを見せても書き込み0件', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_a': 'old'});
    final importer = _FakeImporter()..json = _bundleJson({'kozuchi_a': 'new'});

    await tester.pumpWidget(build(repository, importer));
    await tester.pumpAndSettle();
    await openDialog(tester);

    await tester.tap(find.byKey(BackupAppKeys.cancelRestoreButton));
    await tester.pumpAndSettle();

    expect(repository.store['kozuchi_a'], 'old');
    expect(find.byKey(BackupAppKeys.confirmRestoreDialog), findsNothing);
  });

  testWidgets('探針6: 破損JSONではプレビューを出さず従来の案内に落ちる', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_a': 'old'});
    final importer = _FakeImporter()..json = '{"schemaVersion":1}';

    await tester.pumpWidget(build(repository, importer));
    await tester.pumpAndSettle();
    await openDialog(tester);

    expect(find.text('不正なバックアップファイルです'), findsOneWidget);
    expect(find.byKey(BackupAppKeys.confirmRestoreDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

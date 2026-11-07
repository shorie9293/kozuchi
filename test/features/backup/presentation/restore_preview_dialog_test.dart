import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/backup/data/backup_file_io.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';
import 'package:kozuchi/features/backup/domain/backup_models.dart';
import 'package:kozuchi/features/backup/presentation/backup_keys.dart';
import 'package:kozuchi/features/backup/presentation/backup_screen.dart';

class _FakeExporter implements BackupExporter {
  @override
  Future<void> export({required String json, required String fileName}) async {}
}

class _FakeImporter implements BackupImporter {
  String? jsonToReturn;

  @override
  Future<String?> pickJson() async => jsonToReturn;
}

/// 画面初期化の collect は通し、復元プレビュー用の collect だけ失敗させる。
class _CollectFailsAfterFirst implements BackupRepository {
  final BackupRepository inner;
  int calls = 0;

  _CollectFailsAfterFirst(this.inner);

  @override
  Future<BackupBundle> collect() async {
    calls++;
    if (calls > 1) throw Exception('collect failed');
    return inner.collect();
  }

  @override
  Future<RestoreResult> restore(BackupBundle bundle) => inner.restore(bundle);
}

String _backupJson(Map<String, Object?> entries) => jsonEncode({
      'schemaVersion': 1,
      'exportedAt': '2026-10-07T00:00:00.000Z',
      'entries': entries,
    });

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required BackupRepository repository,
    required _FakeImporter importer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(
          repository: repository,
          exporter: _FakeExporter(),
          importer: importer,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('復元ダイアログに内訳プレビューと上書き対象キーが出る（既存文言は不変）', (tester) async {
    final repository = InMemoryBackupRepository({
      'kozuchi_keep': 'same',
      'kozuchi_change': 'old',
    });
    final importer = _FakeImporter()
      ..jsonToReturn = _backupJson({
        'kozuchi_keep': 'same',
        'kozuchi_change': 'new',
        'kozuchi_new': 'x',
      });

    await pump(tester, repository: repository, importer: importer);
    await tester.tap(find.byKey(BackupAppKeys.restoreButton));
    await tester.pumpAndSettle();

    expect(find.byKey(BackupAppKeys.confirmRestoreDialog), findsOneWidget);

    // 既存の文言が1文字も変わらず残っている
    expect(
      find.text('3件のデータを復元します。\n現在の対象データは上書きされます。よろしいですか？'),
      findsOneWidget,
    );

    // 内訳
    final summary = tester.widget<Text>(
      find.byKey(BackupAppKeys.restorePreviewSummary),
    );
    expect(summary.data, '新規 1件 / 上書き 1件 / 変更なし 1件');

    // 上書き対象キー
    final samples = tester.widget<Text>(
      find.byKey(BackupAppKeys.restorePreviewSamples),
    );
    expect(samples.data, contains('kozuchi_change'));
    expect(samples.data, isNot(contains('kozuchi_new')));
    expect(samples.data, isNot(contains('kozuchi_keep')));

    // 既存ボタン Key は温存
    expect(find.byKey(BackupAppKeys.confirmRestoreButton), findsOneWidget);
    expect(find.byKey(BackupAppKeys.cancelRestoreButton), findsOneWidget);
  });

  testWidgets('全件一致ならサンプル欄を出さず「変更はありません」', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_keep': 'same'});
    final importer = _FakeImporter()
      ..jsonToReturn = _backupJson({'kozuchi_keep': 'same'});

    await pump(tester, repository: repository, importer: importer);
    await tester.tap(find.byKey(BackupAppKeys.restoreButton));
    await tester.pumpAndSettle();

    final summary = tester.widget<Text>(
      find.byKey(BackupAppKeys.restorePreviewSummary),
    );
    expect(summary.data, '新規 0件 / 上書き 0件 / 変更なし 1件');
    expect(find.byKey(BackupAppKeys.restorePreviewSamples), findsNothing);
    expect(find.textContaining('変更はありません'), findsOneWidget);
  });

  testWidgets('collect が失敗してもプレビューだけ省き、従来の文言で復元導線を残す', (tester) async {
    final repository = _CollectFailsAfterFirst(
      InMemoryBackupRepository({'kozuchi_old': 'x'}),
    );
    final importer = _FakeImporter()
      ..jsonToReturn = _backupJson({'kozuchi_old': 'overwritten'});

    await pump(tester, repository: repository, importer: importer);
    await tester.tap(find.byKey(BackupAppKeys.restoreButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(BackupAppKeys.confirmRestoreDialog), findsOneWidget);
    expect(
      find.text('1件のデータを復元します。\n現在の対象データは上書きされます。よろしいですか？'),
      findsOneWidget,
    );
    expect(find.byKey(BackupAppKeys.restorePreviewSummary), findsNothing);
    expect(find.byKey(BackupAppKeys.restorePreviewSamples), findsNothing);

    await tester.tap(find.byKey(BackupAppKeys.confirmRestoreButton));
    await tester.pumpAndSettle();
    expect(repository.calls, greaterThanOrEqualTo(2));
  });
}

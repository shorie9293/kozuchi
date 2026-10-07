import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/backup/data/backup_repository.dart';
import 'package:kozuchi/features/backup/data/backup_file_io.dart';
import 'package:kozuchi/features/backup/domain/backup_models.dart';
import 'package:kozuchi/features/backup/presentation/backup_keys.dart';
import 'package:kozuchi/features/backup/presentation/backup_screen.dart';

class FakeExporter implements BackupExporter {
  String? json;
  String? fileName;
  Object? error;

  @override
  Future<void> export({required String json, required String fileName}) async {
    if (error != null) {
      throw error!;
    }
    this.json = json;
    this.fileName = fileName;
  }
}

class FakeImporter implements BackupImporter {
  String? jsonToReturn;

  @override
  Future<String?> pickJson() async => jsonToReturn;
}

BackupBundle _parse(String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  return BackupBundle.fromJson(map);
}

void main() {
  Widget buildScreen({
    BackupRepository? repository,
    required FakeExporter exporter,
    required FakeImporter importer,
  }) {
    return MaterialApp(
      home: BackupScreen(
        repository: repository,
        exporter: exporter,
        importer: importer,
      ),
    );
  }

  testWidgets('対象キーの件数とキー一覧が表示される', (tester) async {
    final repository = InMemoryBackupRepository({
      'kozuchi_goals': <String>['a'],
      'income_entries': <String>['x'],
      'unrelated': 'ignored',
    });
    await tester.pumpWidget(buildScreen(
      repository: repository,
      exporter: FakeExporter(),
      importer: FakeImporter(),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(BackupAppKeys.entryCountText), findsOneWidget);
    expect(find.text('バックアップ対象: 2件'), findsOneWidget);
    expect(find.byKey(BackupAppKeys.row('kozuchi_goals')), findsOneWidget);
    expect(find.byKey(BackupAppKeys.row('income_entries')), findsOneWidget);
    expect(find.byKey(BackupAppKeys.row('unrelated')), findsNothing);
  });

  testWidgets('エクスポート押下で exporter に parse 可能な JSON が渡る', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_count': 3});
    final exporter = FakeExporter();
    await tester.pumpWidget(buildScreen(
      repository: repository,
      exporter: exporter,
      importer: FakeImporter(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BackupAppKeys.exportButton));
    await tester.pumpAndSettle();

    expect(exporter.fileName, isNotNull);
    expect(exporter.fileName, contains('kozuchi_backup_'));
    expect(exporter.fileName, endsWith('.json'));
    expect(exporter.json, isNotNull);
    final bundle = _parse(exporter.json!);
    expect(bundle.entries['kozuchi_count'], 3);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('バックアップを書き出しました'), findsOneWidget);
  });

  testWidgets('エクスポートで exporter が失敗したら失敗SnackBar', (tester) async {
    final exporter = FakeExporter()..error = Exception('boom');
    await tester.pumpWidget(buildScreen(
      repository: InMemoryBackupRepository({'kozuchi_a': 1}),
      exporter: exporter,
      importer: FakeImporter(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BackupAppKeys.exportButton));
    await tester.pumpAndSettle();

    expect(find.text('バックアップの書き出しに失敗しました'), findsOneWidget);
  });

  testWidgets('復元押下→確認→repository に反映され result.label が SnackBar に出る', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_old': 'x'});
    final importer = FakeImporter()
      ..jsonToReturn = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': '2026-10-07T00:00:00.000Z',
        'entries': {
          'kozuchi_old': 'overwritten',
          'kozuchi_new': 'created',
        },
      });
    await tester.pumpWidget(buildScreen(
      repository: repository,
      exporter: FakeExporter(),
      importer: importer,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BackupAppKeys.restoreButton));
    await tester.pumpAndSettle();

    expect(find.byKey(BackupAppKeys.confirmRestoreDialog), findsOneWidget);
    await tester.tap(find.byKey(BackupAppKeys.confirmRestoreButton));
    await tester.pumpAndSettle();

    expect(repository.store['kozuchi_old'], 'overwritten');
    expect(repository.store['kozuchi_new'], 'created');
    expect(find.text('新規 1件 / 更新 1件 / 変更なし 0件'), findsOneWidget);
    // 再読込で一覧も更新されている
    expect(find.byKey(BackupAppKeys.row('kozuchi_new')), findsOneWidget);
  });

  testWidgets('復元確認ダイアログでキャンセルすると何もしない', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_old': 'x'});
    final importer = FakeImporter()
      ..jsonToReturn = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': '2026-10-07T00:00:00.000Z',
        'entries': {'kozuchi_old': 'overwritten'},
      });
    await tester.pumpWidget(buildScreen(
      repository: repository,
      exporter: FakeExporter(),
      importer: importer,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BackupAppKeys.restoreButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BackupAppKeys.cancelRestoreButton));
    await tester.pumpAndSettle();

    expect(repository.store['kozuchi_old'], 'x');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('不正なバックアップファイルでエラーSnackBar（復元しない）', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_old': 'x'});
    final importer = FakeImporter()..jsonToReturn = 'not json at all';
    await tester.pumpWidget(buildScreen(
      repository: repository,
      exporter: FakeExporter(),
      importer: importer,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BackupAppKeys.restoreButton));
    await tester.pumpAndSettle();

    expect(find.text('不正なバックアップファイルです'), findsOneWidget);
    expect(find.byKey(BackupAppKeys.confirmRestoreDialog), findsNothing);
    expect(repository.store['kozuchi_old'], 'x');
  });

  testWidgets('ピッカーでキャンセル（null）なら何もしない', (tester) async {
    final repository = InMemoryBackupRepository({'kozuchi_old': 'x'});
    await tester.pumpWidget(buildScreen(
      repository: repository,
      exporter: FakeExporter(),
      importer: FakeImporter()..jsonToReturn = null,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BackupAppKeys.restoreButton));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(BackupAppKeys.confirmRestoreDialog), findsNothing);
    expect(repository.store['kozuchi_old'], 'x');
  });

  testWidgets('空 store では emptyText の空状態を表示する', (tester) async {
    await tester.pumpWidget(buildScreen(
      repository: InMemoryBackupRepository({}),
      exporter: FakeExporter(),
      importer: FakeImporter(),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(BackupAppKeys.emptyText), findsOneWidget);
    expect(find.text('バックアップ対象のデータがありません'), findsOneWidget);
    expect(find.byKey(BackupAppKeys.entryCountText), findsNothing);
  });

  testWidgets('screen / appBarTitle / ボタン各Keyが存在する', (tester) async {
    await tester.pumpWidget(buildScreen(
      repository: InMemoryBackupRepository({'kozuchi_a': 1}),
      exporter: FakeExporter(),
      importer: FakeImporter(),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(BackupAppKeys.screen), findsOneWidget);
    expect(find.byKey(BackupAppKeys.appBarTitle), findsOneWidget);
    expect(find.byKey(BackupAppKeys.exportButton), findsOneWidget);
    expect(find.byKey(BackupAppKeys.restoreButton), findsOneWidget);
    expect(find.text('バックアップと復元'), findsOneWidget);
  });
}

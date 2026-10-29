import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:kozuchi/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_keys.dart';
import 'package:kozuchi/features/auto_backup/presentation/auto_backup_screen.dart';

/// 復元呼び出しを記録する試練用フェイク。
class _FakeRestorer implements AutoBackupRestorer {
  final List<String> calls = <String>[];
  bool throwOnRestore = false;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    calls.add(fileName);
    if (throwOnRestore) throw StateError('復元失敗');
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

/// 共有呼び出しを記録する試練用フェイク。
class _FakeSharer implements AutoBackupSharer {
  final List<String> shared = <String>[];

  @override
  Future<void> share(String fileName, String json) async {
    shared.add(fileName);
  }
}

/// 自動バックアップ画面の表示・導線を検める試練。
void main() {
  late InMemoryAutoBackupStore store;
  late DateTime current;

  setUp(() {
    current = DateTime(2026, 10, 29, 7, 12);
    store = InMemoryAutoBackupStore(now: () => current);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    AutoBackupRestorer? restorer,
    AutoBackupSharer? sharer,
    Future<void> Function()? onBackupNow,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AutoBackupScreen(
          store: store,
          restorer: restorer,
          sharer: sharer,
          onBackupNow: onBackupNow,
          now: () => DateTime(2026, 10, 29, 7, 12),
        ),
      ),
    );
    // initState の非同期読込を2段階で進める（アニメーション待ちは避ける）
    await tester.pump();
    await tester.pump();
  }

  testWidgets('0件なら空状態を表示する', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(AutoBackupAppKeys.emptyText), findsOneWidget);
    expect(find.text('バックアップはまだありません'), findsOneWidget);
    expect(find.byKey(AutoBackupAppKeys.list), findsNothing);
  });

  testWidgets('新しい順に並べ、保持件数を表示する', (tester) async {
    current = DateTime(2026, 10, 1, 6, 0);
    await store.write('auto_backup_20261001.json', '{"a":1}');
    current = DateTime(2026, 10, 3, 6, 0);
    await store.write('auto_backup_20261003.json', '{"c":333}');

    await pumpScreen(tester);

    final newest = find.textContaining('2026-10-03');
    final oldest = find.textContaining('2026-10-01');
    expect(newest, findsOneWidget);
    expect(oldest, findsOneWidget);
    expect(
      tester.getTopLeft(newest).dy,
      lessThan(tester.getTopLeft(oldest).dy),
    );
    expect(find.text('保持 3世代中 2件'), findsOneWidget);
    // 最新が第1世代
    expect(find.textContaining('第1世代'), findsOneWidget);
  });

  testWidgets('壊れたJSONの行には復元ボタンを出さない', (tester) async {
    await store.write('auto_backup_20261003.json', '{"ok":1}');
    await store.write('auto_backup_20261002.json', '{broken');

    await pumpScreen(tester, restorer: _FakeRestorer());

    expect(
      find.byKey(
        AutoBackupAppKeys.restoreButton('auto_backup_20261003.json'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        AutoBackupAppKeys.restoreButton('auto_backup_20261002.json'),
      ),
      findsNothing,
    );
  });

  testWidgets('restorer 未注入なら復元ボタンを出さない', (tester) async {
    await store.write('auto_backup_20261003.json', '{"ok":1}');

    await pumpScreen(tester);

    expect(find.byIcon(Icons.restore), findsNothing);
    expect(
      find.byKey(
        AutoBackupAppKeys.restoreButton('auto_backup_20261003.json'),
      ),
      findsNothing,
    );
  });

  testWidgets('sharer 未注入なら共有ボタンを出さない', (tester) async {
    await store.write('auto_backup_20261003.json', '{"ok":1}');

    await pumpScreen(tester);

    expect(
      find.byKey(AutoBackupAppKeys.shareButton('auto_backup_20261003.json')),
      findsNothing,
    );
  });

  testWidgets('確認ダイアログでOKすると復元を呼ぶ', (tester) async {
    await store.write('auto_backup_20261003.json', '{"ok":1}');
    final restorer = _FakeRestorer();

    await pumpScreen(tester, restorer: restorer);
    await tester.tap(
      find.byKey(
        AutoBackupAppKeys.restoreButton('auto_backup_20261003.json'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(AutoBackupAppKeys.confirmDialog), findsOneWidget);
    expect(
      find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
      findsOneWidget,
    );
    expect(restorer.calls, isEmpty);

    await tester.tap(find.byKey(AutoBackupAppKeys.confirmButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(restorer.calls, ['auto_backup_20261003.json']);
    expect(find.text('復元しました'), findsOneWidget);
  });

  testWidgets('確認ダイアログでキャンセルすると復元を呼ばない', (tester) async {
    await store.write('auto_backup_20261003.json', '{"ok":1}');
    final restorer = _FakeRestorer();

    await pumpScreen(tester, restorer: restorer);
    await tester.tap(
      find.byKey(
        AutoBackupAppKeys.restoreButton('auto_backup_20261003.json'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(AutoBackupAppKeys.cancelButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(restorer.calls, isEmpty);
    expect(find.byKey(AutoBackupAppKeys.confirmDialog), findsNothing);
  });

  testWidgets('復元が例外を投げても画面は落とさず通知する', (tester) async {
    await store.write('auto_backup_20261003.json', '{"ok":1}');
    final restorer = _FakeRestorer()..throwOnRestore = true;

    await pumpScreen(tester, restorer: restorer);
    await tester.tap(
      find.byKey(
        AutoBackupAppKeys.restoreButton('auto_backup_20261003.json'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(AutoBackupAppKeys.confirmButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('復元に失敗しました'), findsOneWidget);
  });

  testWidgets('共有ボタンで sharer を呼ぶ', (tester) async {
    await store.write('auto_backup_20261003.json', '{"ok":1}');
    final sharer = _FakeSharer();

    await pumpScreen(tester, sharer: sharer);
    await tester.tap(
      find.byKey(AutoBackupAppKeys.shareButton('auto_backup_20261003.json')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sharer.shared, ['auto_backup_20261003.json']);
  });

  testWidgets('onBackupNow 未注入なら「今すぐバックアップ」を出さない', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(AutoBackupAppKeys.backupNowButton), findsNothing);
  });

  testWidgets('「今すぐバックアップ」で採取を実行し再読込する', (tester) async {
    var runs = 0;

    await pumpScreen(
      tester,
      onBackupNow: () async {
        runs++;
        await store.write('auto_backup_20261029.json', '{"new":true}');
      },
    );

    expect(find.byKey(AutoBackupAppKeys.emptyText), findsOneWidget);

    await tester.tap(find.byKey(AutoBackupAppKeys.backupNowButton));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(runs, 1);
    expect(find.byKey(AutoBackupAppKeys.emptyText), findsNothing);
    expect(find.textContaining('2026-10-29'), findsOneWidget);
  });

  testWidgets('表示ラベルは 日時 / サイズ / 世代 の形式', (tester) async {
    await store.write('auto_backup_20261029.json', 'x' * 12698);

    await pumpScreen(tester);

    expect(
      find.text(
        '${AutoBackupPresenter.formatDate(DateTime(2026, 10, 29, 7, 12))}'
        ' / 12.4 KB / 第1世代',
      ),
      findsOneWidget,
    );
  });
}

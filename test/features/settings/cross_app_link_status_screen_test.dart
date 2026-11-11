import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/infrastructure/cross_app_link_status.dart';
import 'package:kozuchi/core/infrastructure/cross_app_link_status_store.dart';
import 'package:kozuchi/features/settings/presentation/cross_app_link_status_screen.dart';

/// 連携状況画面の試練。
///
/// 成否・時刻・件数・ファイル名・失敗理由が出ること、再読込が効くことを固定する。
void main() {
  final sent = CrossAppTransferRecord(
    at: DateTime(2026, 11, 11, 9, 12),
    ok: true,
    count: 3,
    fileName: 'tsundoku_reward_events.jsonl',
  );
  final failedReceived = CrossAppTransferRecord(
    at: DateTime(2026, 11, 10, 20, 5),
    ok: false,
    count: 0,
    fileName: 'rpg_enemy_defeat_events.json',
    error: 'SharedStorageException(read, rpg_enemy_defeat_events.json): boom',
  );

  Future<CrossAppLinkStatusRecorder> pumpScreen(
    WidgetTester tester,
    CrossAppLinkSnapshot snapshot,
  ) async {
    final store = InMemoryCrossAppLinkStatusStore(snapshot);
    final recorder = CrossAppLinkStatusRecorder(store: store);
    await tester.pumpWidget(MaterialApp(
      home: CrossAppLinkStatusScreen(recorder: recorder),
    ));
    await tester.pump();
    await tester.pump();
    return recorder;
  }

  testWidgets('空状態では送受信ともに「未記録」を出す', (tester) async {
    await pumpScreen(tester, CrossAppLinkSnapshot.empty);

    expect(find.text('連携状況'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(CrossAppLinkStatusScreen.sentKey),
        matching: find.text('未記録'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(CrossAppLinkStatusScreen.receivedKey),
        matching: find.text('未記録'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(CrossAppLinkStatusScreen.folderKey),
        matching: find.textContaining('未設定'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('記録ありなら成否・時刻・件数・ファイル名を出す', (tester) async {
    await pumpScreen(
      tester,
      CrossAppLinkSnapshot(lastSent: sent, sharedFolderReady: true),
    );

    expect(
      find.descendant(
        of: find.byKey(CrossAppLinkStatusScreen.sentKey),
        matching: find.text(
          '成功・2026/11/11 09:12・3件・tsundoku_reward_events.jsonl',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(CrossAppLinkStatusScreen.folderKey),
        matching: find.text('設定済み'),
      ),
      findsOneWidget,
    );
    // 送信だけの記録なので受信は未記録のまま。
    expect(
      find.descendant(
        of: find.byKey(CrossAppLinkStatusScreen.receivedKey),
        matching: find.text('未記録'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('失敗は理由まで表示する', (tester) async {
    await pumpScreen(
      tester,
      CrossAppLinkSnapshot(lastReceived: failedReceived),
    );

    final received = find.byKey(CrossAppLinkStatusScreen.receivedKey);
    expect(
      find.descendant(
        of: received,
        matching:
            find.text('失敗・2026/11/10 20:05・0件・rpg_enemy_defeat_events.json'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: received,
        matching: find.textContaining('SharedStorageException(read'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('再読込キーで最新の記録に更新される', (tester) async {
    final recorder = await pumpScreen(tester, CrossAppLinkSnapshot.empty);

    expect(
      find.descendant(
        of: find.byKey(CrossAppLinkStatusScreen.sentKey),
        matching: find.text('未記録'),
      ),
      findsOneWidget,
    );

    await recorder.recordSent(count: 1, fileName: 'kozuchi_quest.json');
    await tester.pump();
    await tester.tap(find.byKey(CrossAppLinkStatusScreen.refreshKey));
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(CrossAppLinkStatusScreen.sentKey),
        matching: find.textContaining('kozuchi_quest.json'),
      ),
      findsOneWidget,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/infrastructure/cross_app_link_status.dart';
import 'package:kozuchi/core/infrastructure/cross_app_link_status_store.dart';

/// 記録口の契約:
/// - 絶対に throw しない
/// - 書込は直列化され、同時記録でも取りこぼさない
/// - 初回記録の前に保存済みの状態を読み込む（前回起動分を消さない）
void main() {
  late InMemoryCrossAppLinkStatusStore store;
  late CrossAppLinkStatusRecorder recorder;
  final fixedNow = DateTime(2026, 11, 11, 9);

  setUp(() {
    store = InMemoryCrossAppLinkStatusStore();
    recorder = CrossAppLinkStatusRecorder(store: store, now: () => fixedNow);
  });

  test('recordSent は時刻・件数・ファイル名を残して保存する', () async {
    await recorder.recordSent(
      count: 1,
      fileName: 'kozuchi_quest.json',
    );

    final sent = recorder.cached.lastSent;
    expect(sent, isNotNull);
    expect(sent!.ok, isTrue);
    expect(sent.at, fixedNow);
    expect(sent.count, 1);
    expect(sent.fileName, 'kozuchi_quest.json');
    expect(store.saveCount, 1);

    final persisted = await store.load();
    expect(persisted.lastSent?.fileName, 'kozuchi_quest.json');
  });

  test('recordSendFailure は ok=false と理由を残す', () async {
    await recorder.recordSendFailure(
      StateError('boom'),
      fileName: 'kozuchi_quest.json',
    );

    final sent = recorder.cached.lastSent!;
    expect(sent.ok, isFalse);
    expect(sent.count, 0);
    expect(sent.error, contains('boom'));
  });

  test('recordReceived は送信側を壊さず受信側だけ更新する', () async {
    await recorder.recordSent(count: 2, fileName: 'a.json');
    await recorder.recordReceived(count: 4, fileName: 'b.jsonl');

    expect(recorder.cached.lastSent?.fileName, 'a.json');
    expect(recorder.cached.lastReceived?.count, 4);
    expect(recorder.cached.lastReceived?.fileName, 'b.jsonl');
    expect(store.saveCount, 2);
  });

  test('recordFolderReady はフォルダ状態だけを変える', () async {
    await recorder.recordSent(count: 1, fileName: 'a.json');
    await recorder.recordFolderReady(true);

    expect(recorder.cached.sharedFolderReady, isTrue);
    expect(recorder.cached.lastSent?.fileName, 'a.json');

    await recorder.recordFolderReady(false);
    expect(recorder.cached.sharedFolderReady, isFalse);
  });

  test('保存が throw しても呼び出し側へ漏れない', () async {
    store.throwOnSave = true;

    await expectLater(
      recorder.recordSent(count: 1, fileName: 'a.json'),
      completes,
    );

    // 保存は失敗したが、メモリ上の状態は残る。
    expect(recorder.cached.lastSent?.fileName, 'a.json');
  });

  test('並行10件でも取りこぼさず、最後の記録が残る', () async {
    await Future.wait<void>([
      for (var i = 1; i <= 10; i++) recorder.recordSent(count: i),
    ]);

    expect(store.saveCount, 10);
    expect(recorder.cached.lastSent?.count, 10);
    expect((await store.load()).lastSent?.count, 10);
  });

  test('load 前の記録でも保存済みの前回値を消さない', () async {
    final previous = CrossAppLinkSnapshot(
      lastSent: CrossAppTransferRecord(
        at: DateTime(2026, 11, 10, 21),
        ok: true,
        count: 7,
        fileName: 'prev.json',
      ),
      sharedFolderReady: true,
    );
    store = InMemoryCrossAppLinkStatusStore(previous);
    recorder = CrossAppLinkStatusRecorder(store: store, now: () => fixedNow);

    await recorder.recordReceived(count: 3, fileName: 'new.jsonl');

    expect(recorder.cached.sharedFolderReady, isTrue);
    expect(recorder.cached.lastSent?.fileName, 'prev.json');
    expect(recorder.cached.lastReceived?.fileName, 'new.jsonl');
  });

  test('load は保存値を返し、失敗しても空で返す', () async {
    final loaded = await recorder.load();
    expect(loaded.lastSent, isNull);
    expect(loaded.lastReceived, isNull);
    expect(loaded.sharedFolderReady, isFalse);
  });

  test('reset で instance を差し替えられる', () async {
    final injected = CrossAppLinkStatusRecorder(store: store);
    CrossAppLinkStatusRecorder.reset(injected);
    expect(CrossAppLinkStatusRecorder.instance, same(injected));

    CrossAppLinkStatusRecorder.reset();
    expect(CrossAppLinkStatusRecorder.instance, isNot(same(injected)));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/infrastructure/cross_app_link_status_store.dart';
import 'package:kozuchi/core/infrastructure/shared_file_store.dart';

/// [FileSharedFileStore] の送受信が記録口へ流れることの試練。
///
/// 経路（送信＝write/append、受信＝read、フォルダ＝ensureDirectory）ごとに
/// 1 件ずつ記録され、失敗も握り潰さず「送信失敗」として残ることを固定する。
void main() {
  late Directory tempDir;
  late FileSharedFileStore store;
  late InMemoryCrossAppLinkStatusStore statusStore;

  final fixedNow = DateTime(2026, 11, 11, 9, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kozuchi_link_status_');
    store = FileSharedFileStore(tempDir);
    statusStore = InMemoryCrossAppLinkStatusStore();
    CrossAppLinkStatusRecorder.reset(
      CrossAppLinkStatusRecorder(store: statusStore, now: () => fixedNow),
    );
  });

  tearDown(() async {
    CrossAppLinkStatusRecorder.reset();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('writeString は送信1件として記録する', () async {
    await store.writeString('kozuchi_quest.json', '{"id":1}');
    await pumpEventQueue();

    final sent = CrossAppLinkStatusRecorder.instance.cached.lastSent;
    expect(sent, isNotNull);
    expect(sent!.ok, isTrue);
    expect(sent.count, 1);
    expect(sent.at, fixedNow);
    expect(sent.fileName, 'kozuchi_quest.json');
  });

  test('appendLine も送信1件として記録する（名前は呼び出し元）', () async {
    await store.appendLine('kozuchi_reward_events.jsonl', '{"gold":10}');
    await pumpEventQueue();

    final sent = CrossAppLinkStatusRecorder.instance.cached.lastSent!;
    expect(sent.ok, isTrue);
    expect(sent.count, 1);
    expect(sent.fileName, 'kozuchi_reward_events.jsonl');
  });

  test('readString は受信として行数を記録する', () async {
    await store.appendLine('incoming.jsonl', '{"a":1}');
    await store.appendLine('incoming.jsonl', '{"a":2}');
    await store.appendLine('incoming.jsonl', '{"a":3}');
    await pumpEventQueue();

    // 送信の記録は消さず、受信側だけを更新する。
    expect(
      CrossAppLinkStatusRecorder.instance.cached.lastSent?.ok,
      isTrue,
    );

    final content = await store.readString('incoming.jsonl');
    await pumpEventQueue();

    expect(content, isNotNull);
    final received = CrossAppLinkStatusRecorder.instance.cached.lastReceived!;
    expect(received.ok, isTrue);
    expect(received.count, 3);
    expect(received.fileName, 'incoming.jsonl');
  });

  test('存在しないファイルの readString は記録を残さない', () async {
    final content = await store.readString('missing.json');
    await pumpEventQueue();

    expect(content, isNull);
    expect(CrossAppLinkStatusRecorder.instance.cached.lastReceived, isNull);
  });

  test('writeString の失敗は送信失敗（ok=false）として残る', () async {
    // ファイルの位置にディレクトリを置いて書込を失敗させる。
    await Directory('${tempDir.path}/broken.json').create(recursive: true);

    await expectLater(
      store.writeString('broken.json', 'x'),
      throwsA(isA<SharedStorageException>()),
    );
    await pumpEventQueue();

    final sent = CrossAppLinkStatusRecorder.instance.cached.lastSent!;
    expect(sent.ok, isFalse);
    expect(sent.count, 0);
    expect(sent.fileName, 'broken.json');
    expect(sent.error, isNotNull);
  });

  test('ensureDirectory は共有フォルダ状態を記録する', () async {
    final target = Directory('${tempDir.path}/nested/shared');
    final nested = FileSharedFileStore(target);

    expect(await nested.ensureDirectory(), isTrue);
    await pumpEventQueue();

    final folder = CrossAppLinkStatusRecorder.instance.cached;
    expect(folder.sharedFolderReady, isTrue);
  });

  test('delete と exists は記録しない', () async {
    await store.writeString('a.json', 'x');
    await pumpEventQueue();
    final before = CrossAppLinkStatusRecorder.instance.cached;

    expect(await store.exists('a.json'), isTrue);
    expect(await store.delete('a.json'), isTrue);
    await pumpEventQueue();

    final after = CrossAppLinkStatusRecorder.instance.cached;
    expect(after.lastSent?.at, before.lastSent?.at);
    expect(after.lastReceived, isNull);
  });
}

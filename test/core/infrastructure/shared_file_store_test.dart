import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/core/infrastructure/shared_file_store.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/features/achievements/data/cross_app_achievement_aggregator.dart';
import 'package:kozuchi/features/careerCoach/data/careerCoach_book_bonus_service.dart';
import 'package:kozuchi/features/rpg_task_bonus/data/rpg_task_bonus_service.dart';
import 'package:kozuchi/features/shared/data/kozuchi_quest_exporter.dart';
import 'package:kozuchi/features/tsundoku/data/tsundoku_gold_luck_buff_service.dart';

/// メモリ上の [ISharedFileStore]。共有ストア経由の読み書きを試練で観測する。
class _FakeStore implements ISharedFileStore {
  _FakeStore();

  final Map<String, String> files = {};
  final List<String> deleted = [];
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<bool> ensureDirectory() async => true;

  @override
  Future<bool> chooseDirectory() async => true;

  @override
  Future<void> writeString(String fileName, String content) async {
    if (failWrite) {
      throw SharedStorageException('write', fileName, 'boom');
    }
    files[fileName] = content;
  }

  @override
  Future<void> appendLine(String fileName, String line) async {
    if (failWrite) {
      throw SharedStorageException('append', fileName, 'boom');
    }
    files[fileName] = '${files[fileName] ?? ''}$line\n';
  }

  @override
  Future<String?> readString(String fileName) async {
    if (failRead) {
      throw SharedStorageException('read', fileName, 'boom');
    }
    return files[fileName];
  }

  @override
  Future<bool> delete(String fileName) async {
    if (failDelete) {
      throw SharedStorageException('delete', fileName, 'boom');
    }
    deleted.add(fileName);
    return files.remove(fileName) != null;
  }

  @override
  Future<bool> exists(String fileName) async => files.containsKey(fileName);

  @override
  Future<List<String>> listFiles() async => files.keys.toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FileSharedFileStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('shared_file_store_test_');
    store = FileSharedFileStore(tempDir);
    SharedFileStore.reset();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    SharedFileStore.reset();
  });

  group('FileSharedFileStore — 契約', () {
    test('writeString → readString で丸ごと往復する', () async {
      await store.writeString('a.json', '{"k":1}');
      expect(await store.readString('a.json'), '{"k":1}');
    });

    test('appendLine は改行付きで末尾に追記する', () async {
      await store.writeString('a.jsonl', '{"n":1}\n');
      await store.appendLine('a.jsonl', '{"n":2}');
      expect(await store.readString('a.jsonl'), '{"n":1}\n{"n":2}\n');
    });

    test('存在しないファイルの readString は null（例外ではない）', () async {
      expect(await store.readString('missing.json'), isNull);
    });

    test('delete は存在すれば true・以降は false', () async {
      await store.writeString('a.json', 'x');
      expect(await store.delete('a.json'), isTrue);
      expect(await store.delete('a.json'), isFalse);
    });

    test('exists と listFiles が実ファイルを反映する', () async {
      await store.writeString('a.json', 'x');
      expect(await store.exists('a.json'), isTrue);
      expect(await store.exists('b.json'), isFalse);
      expect(await store.listFiles(), ['a.json']);
    });

    test('ensureDirectory は無いディレクトリを作る', () async {
      final nested = Directory('${tempDir.path}/deep/nest');
      final nestedStore = FileSharedFileStore(nested);
      expect(await nestedStore.ensureDirectory(), isTrue);
      expect(nested.existsSync(), isTrue);
    });

    test('書込失敗は SharedStorageException(write) として伝わる', () async {
      // ファイル名と同じ名前のディレクトリを作り、書込を失敗させる
      Directory('${tempDir.path}/bad.json').createSync();
      await expectLater(
        store.writeString('bad.json', 'x'),
        throwsA(
          isA<SharedStorageException>()
              .having((e) => e.operation, 'operation', 'write')
              .having((e) => e.fileName, 'fileName', 'bad.json')
              .having((e) => e.cause, 'cause', isNotNull),
        ),
      );
    });

    test('読取失敗（不正 UTF-8）は SharedStorageException(read) として伝わる', () async {
      File('${tempDir.path}/broken.json')
          .writeAsBytesSync([0xFF, 0xFE, 0xFD, 0xFC]);
      await expectLater(
        store.readString('broken.json'),
        throwsA(
          isA<SharedStorageException>()
              .having((e) => e.operation, 'operation', 'read'),
        ),
      );
    });
  });

  group('AndroidSharedFileStore — MethodChannel', () {
    const channel = MethodChannel('com.shorie.kozuchi/shared_storage');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    void mock(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return handler(call);
      });
    }

    test('readString は契約名を渡し、null はそのまま null（未連携）', () async {
      mock((call) async {
        if (call.method == 'ensureDirectory') return true;
        return null;
      });

      final android = AndroidSharedFileStore(channel: channel);
      expect(await android.readString('tsundoku_book_events.json'), isNull);
      final read = calls.firstWhere((c) => c.method == 'readString');
      expect(
        (read.arguments as Map)['name'],
        'tsundoku_book_events.json',
      );
    });

    test('MethodChannel の PlatformException は SharedStorageException になる',
        () async {
      mock((call) async {
        if (call.method == 'ensureDirectory') return true;
        throw PlatformException(code: 'read_failed', message: 'denied');
      });

      final android = AndroidSharedFileStore(channel: channel);
      await expectLater(
        android.readString('rpg_enemy_defeat_events.json'),
        throwsA(
          isA<SharedStorageException>()
              .having(
                  (e) => e.fileName, 'fileName', 'rpg_enemy_defeat_events.json')
              .having((e) => e.cause, 'cause', isA<PlatformException>()),
        ),
      );
    });

    test('フォルダ未設定なら writeString は失敗を例外で返す（無音成功にしない）', () async {
      mock((call) async => false);

      final android = AndroidSharedFileStore(channel: channel);
      await expectLater(
        android.writeString('kozuchi_quest.json', '{}'),
        throwsA(isA<SharedStorageException>()),
      );
      expect(
        calls.any((c) => c.method == 'writeString'),
        isFalse,
        reason: '未設定時に書込を送ってはならない',
      );
    });

    test('writeString / appendLine は name と本文を送る', () async {
      mock((call) async => true);

      final android = AndroidSharedFileStore(channel: channel);
      await android.writeString('kozuchi_quest.json', '{"a":1}');
      await android.appendLine('rpg_enemy_defeat_events.jsonl', '{"b":2}');

      final write = calls.firstWhere((c) => c.method == 'writeString');
      expect((write.arguments as Map)['name'], 'kozuchi_quest.json');
      expect((write.arguments as Map)['content'], '{"a":1}');

      final append = calls.firstWhere((c) => c.method == 'appendLine');
      expect(
          (append.arguments as Map)['name'], 'rpg_enemy_defeat_events.jsonl');
      expect((append.arguments as Map)['line'], '{"b":2}');
    });

    test('delete / exists / listFiles はチャネル応答をそのまま返す', () async {
      mock((call) async {
        switch (call.method) {
          case 'ensureDirectory':
            return true;
          case 'delete':
            return true;
          case 'exists':
            return false;
          case 'listFiles':
            return <String>['a.json', 'b.json'];
        }
        return null;
      });

      final android = AndroidSharedFileStore(channel: channel);
      expect(await android.delete('a.json'), isTrue);
      expect(await android.exists('a.json'), isFalse);
      expect(await android.listFiles(), ['a.json', 'b.json']);
    });

    test('chooseDirectory は選択メソッドを 1 回だけ呼ぶ', () async {
      mock((call) async => true);

      final android = AndroidSharedFileStore(channel: channel);
      expect(await android.chooseDirectory(), isTrue);
      expect(
        calls.where((c) => c.method == 'chooseDirectory').length,
        1,
      );
    });
  });

  group('共有ストア注入 — 読取サービスが契約名で読む', () {
    test('TsundokuGoldLuckBuffService は tsundoku_book_completed.json を消費する',
        () async {
      final fake = _FakeStore()
        ..files[SharedCrossAppFiles.tsundokuBookCompleted] =
            jsonEncode({'event': 'book_completed', 'bookTitle': '神書'});
      SharedFileStore.configure(fake);

      final buff = await const TsundokuGoldLuckBuffService().checkAndConsume();

      expect(buff, isNotNull);
      expect(buff!.bookTitle, '神書');
      expect(fake.deleted, [SharedCrossAppFiles.tsundokuBookCompleted]);
    });

    test('CareerCoachBookBonusService は tsundoku_book_events.json を読む',
        () async {
      final fake = _FakeStore()
        ..files[SharedCrossAppFiles.tsundokuBookEvents] =
            jsonEncode({'event': 'book_added', 'bookTitle': '古事記'});
      SharedFileStore.configure(fake);

      final result = await const CareerCoachBookBonusService()
          .checkAndConsume(Advisor.benzaiten);

      expect(result, isNotNull);
      expect(result!.bookTitle, '古事記');
      expect(fake.deleted, [SharedCrossAppFiles.tsundokuBookEvents]);
    });

    test('RpgTaskBonusService は rpg_enemy_defeat_events.json を読む', () async {
      final fake = _FakeStore()
        ..files[SharedCrossAppFiles.rpgEnemyDefeatJson] =
            jsonEncode({'event': 'enemy_defeated', 'questRank': 'S'});
      SharedFileStore.configure(fake);

      final result = await const RpgTaskBonusService().checkAndConsume();

      expect(result, isNotNull);
      expect(result!.bonusExp, 50);
      expect(fake.deleted, [SharedCrossAppFiles.rpgEnemyDefeatJson]);
    });

    test('CrossAppAchievementAggregator は jsonl と単一 JSON を共有ストアから数える',
        () async {
      final fake = _FakeStore()
        ..files[SharedCrossAppFiles.rpgEnemyDefeatJsonl] = [
          jsonEncode({'event': 'enemy_defeated'}),
          jsonEncode({'event': 'enemy_defeated'}),
          jsonEncode({'event': 'book_added'}),
        ].join('\n')
        ..files[SharedCrossAppFiles.tsundokuBookCompleted] =
            jsonEncode({'event': 'book_completed'})
        ..files[SharedCrossAppFiles.tsundokuRewardEvents] =
            jsonEncode({'event_type': 'book_completed'});
      SharedFileStore.configure(fake);

      const aggregator = CrossAppAchievementAggregator();

      expect(await aggregator.countEnemyDefeats(), 2);
      expect(await aggregator.countBooksRead(), 2);
    });

    test('KozuchiQuestExporter は kozuchi_quest.json を共有ストアへ書く', () async {
      final fake = _FakeStore();
      SharedFileStore.configure(fake);

      await const KozuchiQuestExporter().export(
        TrialQuest(
          title: '賽銭を貯めよ',
          description: '今月は外食を月2回までに抑える',
          suggestedOffering: 300,
          advisor: Advisor.benzaiten,
        ),
      );

      final written = fake.files[SharedCrossAppFiles.kozuchiQuest];
      expect(written, isNotNull);
      final json = jsonDecode(written!) as Map<String, dynamic>;
      expect(json['title'], '賽銭を貯めよ');
      expect(json['advisor'], 'benzaiten');
    });

    test('読取失敗は無音で捨てず SharedStorageException として上位へ出る', () async {
      final fake = _FakeStore()..failRead = true;
      SharedFileStore.configure(fake);

      await expectLater(
        const TsundokuGoldLuckBuffService().checkAndConsume(),
        throwsA(isA<SharedStorageException>()),
      );
      await expectLater(
        const CareerCoachBookBonusService().checkAndConsume(Advisor.benzaiten),
        throwsA(isA<SharedStorageException>()),
      );
      await expectLater(
        const RpgTaskBonusService().checkAndConsume(),
        throwsA(isA<SharedStorageException>()),
      );
      await expectLater(
        const CrossAppAchievementAggregator().countBooksRead(),
        throwsA(isA<SharedStorageException>()),
      );
    });

    test('書出失敗も無音にせず SharedStorageException として上位へ出る', () async {
      SharedFileStore.configure(_FakeStore()..failWrite = true);

      await expectLater(
        const KozuchiQuestExporter().export(
          TrialQuest(
            title: 't',
            description: 'd',
            suggestedOffering: 1,
            advisor: Advisor.benzaiten,
          ),
        ),
        throwsA(isA<SharedStorageException>()),
      );
    });
  });

  group('後方互換 — filePath / basePath 注入時は直書きを保つ', () {
    test('TsundokuGoldLuckBuffService(filePath:) は共有ストアを見ない', () async {
      final fake = _FakeStore();
      SharedFileStore.configure(fake);

      final path = '${tempDir.path}/tsundoku_book_completed.json';
      File(path).writeAsStringSync(
        jsonEncode({'event': 'book_completed', 'bookTitle': '直書き'}),
      );

      final buff =
          await TsundokuGoldLuckBuffService(filePath: path).checkAndConsume();

      expect(buff!.bookTitle, '直書き');
      expect(File(path).existsSync(), isFalse, reason: '消費で削除されること');
      expect(fake.files, isEmpty);
    });

    test('CrossAppAchievementAggregator(basePath:) は直読みを保つ', () async {
      final fake = _FakeStore();
      SharedFileStore.configure(fake);
      SharedPreferences.setMockInitialValues({});

      File('${tempDir.path}/rpg_enemy_defeat_events.jsonl')
          .writeAsStringSync(jsonEncode({'event': 'enemy_defeated'}));

      final count = await CrossAppAchievementAggregator(basePath: tempDir.path)
          .countEnemyDefeats();

      expect(count, 1);
      expect(fake.files, isEmpty);
    });
  });
}

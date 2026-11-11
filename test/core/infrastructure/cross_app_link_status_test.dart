import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/core/infrastructure/cross_app_link_status.dart';

/// 現世間の受け渡し状態の**純粋**な試練。
///
/// 破損した保存値は日常的に起こるため、decode 系は例外を投げないことを固定する。
void main() {
  group('CrossAppTransferRecord', () {
    test('toJson → tryFromJson で全項目が往復する', () {
      final record = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 12),
        ok: true,
        count: 3,
        fileName: 'tsundoku_reward_events.jsonl',
      );

      final restored = CrossAppTransferRecord.tryFromJson(record.toJson());

      expect(restored, isNotNull);
      expect(restored!.at, DateTime(2026, 11, 11, 9, 12));
      expect(restored.ok, isTrue);
      expect(restored.count, 3);
      expect(restored.fileName, 'tsundoku_reward_events.jsonl');
      expect(restored.error, isNull);
    });

    test('失敗記録は error を保持したまま往復する', () {
      final record = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 12),
        ok: false,
        count: 0,
        fileName: 'kozuchi_quest.json',
        error: 'SharedStorageException(write, kozuchi_quest.json): boom',
      );

      final restored = CrossAppTransferRecord.tryFromJson(record.toJson())!;

      expect(restored.ok, isFalse);
      expect(restored.count, 0);
      expect(restored.error, contains('SharedStorageException'));
    });

    test('Map でない値・null は例外を投げず null を返す', () {
      expect(CrossAppTransferRecord.tryFromJson(null), isNull);
      expect(CrossAppTransferRecord.tryFromJson('文字列'), isNull);
      expect(CrossAppTransferRecord.tryFromJson(<Object?>[1, 2]), isNull);
    });

    test('at が欠落・不正なら null を返す', () {
      expect(
        CrossAppTransferRecord.tryFromJson(<String, Object?>{'ok': true}),
        isNull,
      );
      expect(
        CrossAppTransferRecord.tryFromJson(
          <String, Object?>{'at': 'not-a-date', 'ok': true},
        ),
        isNull,
      );
      expect(
        CrossAppTransferRecord.tryFromJson(
          <String, Object?>{'at': 20261111, 'ok': true},
        ),
        isNull,
      );
    });

    test('count が数値でない・欠落なら 0 に落とす', () {
      final fromString = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T09:12:00.000',
        'ok': true,
        'count': '3',
      })!;
      final missing = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T09:12:00.000',
        'ok': true,
      })!;
      final numValue = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T09:12:00.000',
        'ok': true,
        'count': 4.0,
      })!;

      expect(fromString.count, 0);
      expect(missing.count, 0);
      expect(numValue.count, 4);
    });

    test('空文字の file / error は null として扱う', () {
      final restored = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T09:12:00.000',
        'ok': false,
        'count': 0,
        'file': '',
        'error': '',
      })!;

      expect(restored.fileName, isNull);
      expect(restored.error, isNull);
    });
  });

  group('CrossAppLinkSnapshot', () {
    test('encode → decode で送信・受信・フォルダ状態が往復する', () {
      final snapshot = CrossAppLinkSnapshot(
        lastSent: CrossAppTransferRecord(
          at: DateTime(2026, 11, 11, 9, 0),
          ok: true,
          count: 1,
          fileName: 'kozuchi_quest.json',
        ),
        lastReceived: CrossAppTransferRecord(
          at: DateTime(2026, 11, 10, 20, 30),
          ok: false,
          count: 0,
          error: 'read failed',
        ),
        sharedFolderReady: true,
      );

      final restored = CrossAppLinkSnapshot.decode(snapshot.encode());

      expect(restored.sharedFolderReady, isTrue);
      expect(restored.lastSent?.fileName, 'kozuchi_quest.json');
      expect(restored.lastSent?.count, 1);
      expect(restored.lastReceived?.ok, isFalse);
      expect(restored.lastReceived?.error, 'read failed');
    });

    test('壊れた JSON は例外を投げず empty になる', () {
      expect(CrossAppLinkSnapshot.decode('{壊れた'), CrossAppLinkSnapshot.empty);
      expect(CrossAppLinkSnapshot.decode('null'), CrossAppLinkSnapshot.empty);
      expect(
          CrossAppLinkSnapshot.decode('[1,2,3]'), CrossAppLinkSnapshot.empty);
      expect(CrossAppLinkSnapshot.decode(null), CrossAppLinkSnapshot.empty);
      expect(CrossAppLinkSnapshot.decode('   '), CrossAppLinkSnapshot.empty);
    });

    test('中身の型が違っても落ちず、読める項目だけ残す', () {
      final restored = CrossAppLinkSnapshot.decode(
        '{"sharedFolderReady":"true","lastSent":"oops"}',
      );

      expect(restored.sharedFolderReady, isFalse);
      expect(restored.lastSent, isNull);
      expect(restored.lastReceived, isNull);
    });

    test('copyWith は指定した項目だけ差し替える', () {
      final sent = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 0),
        ok: true,
        count: 2,
      );
      final received = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 10, 0),
        ok: true,
        count: 5,
      );
      const base = CrossAppLinkSnapshot(sharedFolderReady: false);

      final withSent = base.copyWith(lastSent: sent);
      final full = withSent.copyWith(
        lastReceived: received,
        sharedFolderReady: true,
      );

      expect(withSent.lastSent, same(sent));
      expect(withSent.lastReceived, isNull);
      expect(withSent.sharedFolderReady, isFalse);
      expect(full.lastSent, same(sent));
      expect(full.lastReceived, same(received));
      expect(full.sharedFolderReady, isTrue);
    });
  });

  group('CrossAppLinkStatusText', () {
    test('time は 2026/11/11 09:12 形式にゼロ埋めし、null は未記録', () {
      expect(CrossAppLinkStatusText.time(null), '未記録');
      expect(
        CrossAppLinkStatusText.time(DateTime(2026, 1, 2, 3, 4)),
        '2026/01/02 03:04',
      );
    });

    test('outcome は 成功／失敗／未記録', () {
      final ok = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11),
        ok: true,
        count: 1,
      );
      final ng = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11),
        ok: false,
        count: 0,
      );

      expect(CrossAppLinkStatusText.outcome(null), '未記録');
      expect(CrossAppLinkStatusText.outcome(ok), '成功');
      expect(CrossAppLinkStatusText.outcome(ng), '失敗');
    });

    test('row は 成否・時刻・件数・ファイル名を並べる', () {
      final ok = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 12),
        ok: true,
        count: 3,
        fileName: 'tsundoku_reward_events.jsonl',
      );

      expect(
        CrossAppLinkStatusText.row(ok),
        '成功・2026/11/11 09:12・3件・tsundoku_reward_events.jsonl',
      );
      expect(CrossAppLinkStatusText.row(null), '未記録');
    });

    test('row はファイル名が無ければ件数で終わる', () {
      final record = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 12),
        ok: false,
        count: 0,
      );

      expect(CrossAppLinkStatusText.row(record), '失敗・2026/11/11 09:12・0件');
    });

    test('folder は 設定済み／未設定 を出し分ける', () {
      expect(CrossAppLinkStatusText.folder(true), '設定済み');
      expect(CrossAppLinkStatusText.folder(false), contains('未設定'));
    });

    test('detail は失敗理由を出し、成功・未記録なら空、長文は切り詰める', () {
      final failed = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11),
        ok: false,
        count: 0,
        error: 'x' * 400,
      );
      final ok = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11),
        ok: true,
        count: 1,
      );

      expect(CrossAppLinkStatusText.detail(null), isEmpty);
      expect(CrossAppLinkStatusText.detail(ok), isEmpty);
      expect(CrossAppLinkStatusText.detail(failed).length, 161);
      expect(CrossAppLinkStatusText.detail(failed), endsWith('…'));
    });

    test('countLines は JSONL の行数を数え、空・null は 0', () {
      expect(CrossAppLinkStatusText.countLines(null), 0);
      expect(CrossAppLinkStatusText.countLines(''), 0);
      expect(CrossAppLinkStatusText.countLines('  \n '), 0);
      expect(CrossAppLinkStatusText.countLines('{"a":1}'), 1);
      expect(CrossAppLinkStatusText.countLines('{"a":1}\n{"b":2}\n'), 2);
    });
  });
}

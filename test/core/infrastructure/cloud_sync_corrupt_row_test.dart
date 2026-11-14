import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// クラウド復元経路の「1行の型不整合で全件復元が失敗する」欠陥に対する試練。
///
/// 契約: `loadExpenseEntries` / `loadExpenseEntriesResult` は
/// **型不整合な行があっても throw しない**。壊れた行は数えて読み飛ばし、
/// 読めた行だけを返す。応答がリストでない場合は照合不能として報告する。
const _userId = 'corrupt-row-user';

/// 固定の JSON 本文を返す Supabase クライアントを作る。
///
/// [bodiesByTable] にテーブル名（URL 末尾セグメント）ごとの本文を渡す。
/// 未指定のテーブルは `[]` を返す。
SupabaseClient _clientWith(Map<String, String> bodiesByTable) {
  final mock = MockClient((request) async {
    final table = request.url.path.split('/').last;
    final body = bodiesByTable[table] ?? '[]';
    return Response(
      body,
      200,
      request: request,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return SupabaseClient('http://fake-supabase:9999', 'fake-key',
      httpClient: mock);
}

/// 正常な expense_entries 行。
Map<String, dynamic> _row({
  String id = 'ok-1',
  Object? amount = 500,
  String category = 'food',
  String date = '2026-06-25T00:00:00.000Z',
}) {
  return {
    'id': id,
    'user_id': _userId,
    'amount': amount,
    'category': category,
    'date': date,
    'note': null,
    'receipt_image_path': null,
    'updated_at': '2026-06-25T12:00:00.000Z',
  };
}

void main() {
  group('破損行を含むクラウド復元', () {
    test('P1: amount が String の行1件 + 正常2件 → 2件復元・skipped 1・throw しない',
        () async {
      final client = _clientWith({
        'expense_entries': json.encode([
          _row(id: 'bad-amount', amount: '100'),
          _row(id: 'ok-a', amount: 300),
          _row(id: 'ok-b', amount: 700),
        ]),
      });
      addTearDown(client.dispose);
      final service = CloudSyncService(client: client);

      final result = await service.loadExpenseEntriesResult(userId: _userId);

      expect(result.entries.length, 2);
      expect(result.entries.map((e) => e.id).toSet(), {'ok-a', 'ok-b'});
      expect(result.skippedCount, 1);
      expect(result.canVerify, isTrue);

      // 旧 API も同じ内容を返す（呼出側は無改変で恩恵を受ける）。
      final legacy = await service.loadExpenseEntries(userId: _userId);
      expect(legacy.length, 2);
    });

    test('P2: id 欠落行 → throw せず skipped に計上', () async {
      final missingId = _row(id: 'ok-a')..remove('id');
      final client = _clientWith({
        'expense_entries':
            json.encode([missingId, _row(id: 'ok-b', amount: 900)]),
      });
      addTearDown(client.dispose);
      final service = CloudSyncService(client: client);

      final result = await service.loadExpenseEntriesResult(userId: _userId);

      expect(result.entries.single.id, 'ok-b');
      expect(result.skippedCount, 1);
      expect(result.canVerify, isTrue);
    });

    test('P3: 全行正常 → skipped 0・件数一致（回帰）', () async {
      final client = _clientWith({
        'expense_entries': json.encode([
          _row(id: 'a', amount: 100),
          _row(id: 'b', amount: 200),
          _row(id: 'c', amount: 300),
        ]),
      });
      addTearDown(client.dispose);
      final service = CloudSyncService(client: client);

      final result = await service.loadExpenseEntriesResult(userId: _userId);

      expect(result.skippedCount, 0);
      expect(result.canVerify, isTrue);
      expect(result.entries.length, 3);
      // date 降順（同値だが順序は保たれる）・ローカル瞬間へ正規化されている。
      expect(result.entries.every((e) => !e.date.isUtc), isTrue);
    });

    test('P4: 応答が List でない（Map）→ throw せず canVerify false', () async {
      final client = _clientWith({
        'expense_entries': json.encode({'message': 'not a list'}),
      });
      addTearDown(client.dispose);
      final service = CloudSyncService(client: client);

      final result = await service.loadExpenseEntriesResult(userId: _userId);

      expect(result.canVerify, isFalse);
      expect(result.entries, isEmpty);
      expect(result.skippedCount, 0);

      // 旧 API も例外を投げない（空を返す）。
      final legacy = await service.loadExpenseEntries(userId: _userId);
      expect(legacy, isEmpty);
    });

    test('P5: loadExpenseEntries のシグネチャと内容が不変（回帰）', () async {
      // シグネチャ: 名前付き引数 userId / lastSyncAt、戻り List<ExpenseEntry>。
      expect(
        CloudSyncService.new,
        isA<CloudSyncService Function({required SupabaseClient client})>(),
      );
      final client = _clientWith({
        'expense_entries': json.encode([_row(id: 'x', amount: 420)]),
      });
      addTearDown(client.dispose);
      final service = CloudSyncService(client: client);

      final List<ExpenseEntry> entries =
          await service.loadExpenseEntries(userId: _userId);
      expect(entries.single.id, 'x');
      expect(entries.single.amount, 420);
      expect(entries.single.category, 'food');

      final filtered = await service.loadExpenseEntries(
        userId: _userId,
        lastSyncAt: DateTime.utc(2026, 6, 1),
      );
      expect(filtered.length, 1);
    });

    test('P6: tryRowToExpenseJson は型だけを見て null/非null を返す', () {
      // double → null（int でない）
      expect(
        CloudSyncService.tryRowToExpenseJson(_row(amount: 100.0)),
        isNull,
      );
      // String → null
      expect(
        CloudSyncService.tryRowToExpenseJson(_row(amount: '100')),
        isNull,
      );
      // Map でない → null
      expect(CloudSyncService.tryRowToExpenseJson(null), isNull);
      expect(CloudSyncService.tryRowToExpenseJson('garbage'), isNull);
      // 正常行 → 非 null かつ receiptImagePath へキー名を変換
      final json = CloudSyncService.tryRowToExpenseJson({
        ...(_row(amount: 300)),
        'receipt_image_path': '/r.jpg',
      });
      expect(json, isNotNull);
      expect(json!['amount'], 300);
      expect(json['receiptImagePath'], '/r.jpg');
      // 意味の検証（amount<=0）は写像では行わない（tryFromJson の責務）。
      expect(CloudSyncService.tryRowToExpenseJson(_row(amount: 0)), isNotNull);
      expect(ExpenseEntry.tryFromJson(_row(amount: 0)), isNull);
    });

    test('P7: ソース不変条件 — 写像に as String / as int が残っていない', () {
      final source = File(
        'lib/core/infrastructure/cloud_sync_service.dart',
      ).readAsStringSync();
      final start = source.indexOf('static Map<String, dynamic>? '
          'tryRowToExpenseJson(Object? row)');
      expect(start, greaterThan(-1), reason: 'tryRowToExpenseJson が見つからない');

      final functionBody = source.substring(start);
      expect(functionBody.contains('as String'), isFalse,
          reason: '写像に as String が残っている');
      expect(functionBody.contains('as int'), isFalse,
          reason: '写像に as int が残っている');
      // 旧写像（二重実装）が残っていないこと。
      expect(source.contains('_rowToExpenseJson'), isFalse,
          reason: '旧 _rowToExpenseJson が残っている');
    });
  });

  group('SupabaseExpenseRepository が読み飛ばしを公開する', () {
    test('P8: 破損行を読むと lastSkippedCount が増え、画面が気づける', () async {
      final client = _clientWith({
        'expense_entries': json.encode([
          _row(id: 'bad', amount: '999'),
          _row(id: 'good', amount: 1200),
        ]),
      });
      addTearDown(client.dispose);
      final repo = SupabaseExpenseRepository(
        cloudStore: CloudSyncService(client: client),
        userIdProvider: () => _userId,
      );

      final entries = await repo.getEntries(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31),
      );

      expect(entries.single.id, 'good');
      expect(repo.lastSkippedCount, 1);
      expect(repo.lastCanVerify, isTrue);
    });

    test('P9: 照合不能（非リスト応答）→ lastCanVerify false・throw しない', () async {
      final client = _clientWith({
        'expense_entries': json.encode({'message': 'schema changed'}),
      });
      addTearDown(client.dispose);
      final repo = SupabaseExpenseRepository(
        cloudStore: CloudSyncService(client: client),
        userIdProvider: () => _userId,
      );

      final count = await repo.getEntryCount();

      expect(count, 0);
      expect(repo.lastCanVerify, isFalse);
    });
  });

  group('downloadAll の読み飛ばし件数', () {
    test('expense_entries_skipped を追加し、既存キーは不変', () async {
      final client = _clientWith({
        'expense_entries': json.encode([
          _row(id: 'bad', amount: '999'),
          _row(id: 'good', amount: 999),
        ]),
        'player_saves': '{}',
        'daily_quests': '{}',
        'weekly_quests': '{}',
        'trial_quest': '{}',
      });
      addTearDown(client.dispose);
      final service = CloudSyncService(client: client);

      final all = await service.downloadAll(userId: _userId);

      expect(all['expense_entries_skipped'], 1);
      expect((all['expense_entries'] as List).length, 1);
      // 既存キーは不変（後方互換）。
      expect(all.containsKey('player_save'), isTrue);
      expect(all.containsKey('daily_quests'), isTrue);
      expect(all.containsKey('weekly_quests'), isTrue);
      expect(all.containsKey('trial_quest'), isTrue);
    });
  });
}

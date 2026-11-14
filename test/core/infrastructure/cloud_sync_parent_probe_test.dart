import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/services/expense_cloud_store.dart';
import 'package:kozuchi/domain/services/supabase_expense_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 親探針（イシコリドメが独立に作成）。
///
/// 眷属の試練は「実装した関数の個別挙動」しか撃たない。
/// ここでは合成（写像→型判定→意味判定→リポジトリ→読み飛ばし件数）と、
/// 後方互換（結果型を持たない旧フェイク）を撃つ。
const _userId = 'parent-probe-user';

SupabaseClient _clientWith(String expenseBody) {
  final mock = MockClient((request) async {
    final table = request.url.path.split('/').last;
    final body = table == 'expense_entries' ? expenseBody : '[]';
    return Response(body, 200,
        request: request,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
  return SupabaseClient('http://fake-probe:9999', 'probe-key',
      httpClient: mock);
}

Map<String, dynamic> _row(String id, Object? amount, {String? date}) => {
      'id': id,
      'user_id': _userId,
      'amount': amount,
      'category': 'food',
      'date': date ?? '2026-06-25T00:00:00.000Z',
      'note': null,
      'receipt_image_path': null,
      'updated_at': '2026-06-25T12:00:00.000Z',
    };

/// 結果型を持たない旧来のフェイク（`implements ExpenseCloudStore` のみ）。
/// 後方互換の要: これがコンパイル・実行できること自体が不変条件。
class _LegacyFakeStore implements ExpenseCloudStore {
  _LegacyFakeStore(this.entries);
  final List<ExpenseEntry> entries;

  @override
  Future<void> saveExpenseEntries(List<ExpenseEntry> entries,
      {required String userId}) async {}

  @override
  Future<List<ExpenseEntry>> loadExpenseEntries(
          {required String userId, DateTime? lastSyncAt}) async =>
      entries;

  @override
  Future<void> deleteExpenseEntry(String id, {required String userId}) async {}
}

void main() {
  group('親探針: 復元経路の合成不変条件', () {
    test('PP1 意味の二重定義なし: amount<=0 は写像を通り、tryFromJson が読み飛ばす', () async {
      final client = _clientWith(json.encode([
        _row('zero', 0),
        _row('minus', -5),
        _row('ok', 120),
      ]));
      addTearDown(client.dispose);
      final result = await CloudSyncService(client: client)
          .loadExpenseEntriesResult(userId: _userId);

      // 写像は型だけを見る（0/-5 は int なので通す）＝意味判定は一箇所。
      expect(CloudSyncService.tryRowToExpenseJson(_row('zero', 0)),
          isNotNull);
      expect(result.entries.map((e) => e.id), ['ok']);
      expect(result.skippedCount, 2);
      expect(result.canVerify, isTrue);
    });

    test('PP2 実データ型の揺れ: num(100.0) でも throw せず読み飛ばす', () async {
      final client = _clientWith(json.encode([
        _row('double', 100.0),
        _row('ok', 900),
      ]));
      addTearDown(client.dispose);
      final result = await CloudSyncService(client: client)
          .loadExpenseEntriesResult(userId: _userId);

      expect(result.entries.map((e) => e.id), ['ok']);
      expect(result.skippedCount, 1);
    });

    test('PP3 日付破損行も読み飛ばす（throw しない）', () async {
      final client = _clientWith(json.encode([
        _row('bad-date', 100, date: 'not-a-date'),
        _row('ok', 100),
      ]));
      addTearDown(client.dispose);
      final result = await CloudSyncService(client: client)
          .loadExpenseEntriesResult(userId: _userId);

      expect(result.entries.length, 1);
      expect(result.skippedCount, 1);
    });

    test('PP4 リポジトリ合成: 読み飛ばし件数が lastSkippedCount へ届く', () async {
      final client = _clientWith(json.encode([
        _row('bad', '100'),
        _row('ok-a', 300),
        _row('ok-b', 200),
      ]));
      addTearDown(client.dispose);
      final repo = SupabaseExpenseRepository(
        cloudStore: CloudSyncService(client: client),
        userIdProvider: () => _userId,
      );

      final entries = await repo.getEntries(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31),
      );

      expect(entries.length, 2);
      expect(repo.lastSkippedCount, 1);
      expect(repo.lastCanVerify, isTrue);
    });

    test('PP5 後方互換: 結果型を持たない旧フェイクでも throw せず skipped 0', () async {
      final entry = ExpenseEntry(
        id: 'legacy-1',
        amount: 50,
        category: 'food',
        date: DateTime(2026, 6, 25, 9),
      );
      final repo = SupabaseExpenseRepository(
        cloudStore: _LegacyFakeStore([entry]),
        userIdProvider: () => _userId,
      );

      final entries = await repo.getEntries(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31),
      );

      expect(entries.length, 1);
      expect(repo.lastSkippedCount, 0);
      expect(repo.lastCanVerify, isTrue);
    });

    test('PP6 downloadAll が読み飛ばし件数を運ぶ（既存キーは不変）', () async {
      final client = _clientWith(json.encode([
        _row('bad', 'oops'),
        _row('ok', 400),
      ]));
      addTearDown(client.dispose);
      final all =
          await CloudSyncService(client: client).downloadAll(userId: _userId);

      expect(all['expense_entries'], hasLength(1));
      expect(all['expense_entries_skipped'], 1);
      // 既存キーの回帰（消していないこと）。
      for (final key in const [
        'player_save',
        'expense_entries',
        'daily_quests',
        'weekly_quests',
        'trial_quest',
      ]) {
        expect(all.containsKey(key), isTrue, reason: 'missing $key');
      }
    });

    test('PP7 ソース不変条件: 写像に as キャストが戻っていない', () {
      final source =
          File('lib/core/infrastructure/cloud_sync_service.dart').readAsStringSync();
      final start = source.indexOf('static Map<String, dynamic>? tryRowToExpenseJson');
      expect(start, greaterThan(0), reason: '写像関数が見つからない');
      final body = source.substring(start, source.indexOf('\n  }', start));
      expect(body.contains(' as '), isFalse,
          reason: '写像に as キャストが残っている（throw 契約違反）: $body');
    });
  });
}

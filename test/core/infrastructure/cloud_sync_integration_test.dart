import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:kozuchi/core/infrastructure/cloud_sync_service.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory fake Supabase "server" for integration tests.
///
/// Tracks per-table state and responds to REST API requests exactly as
/// Supabase's PostgREST interface would, enabling full lifecycle tests
/// without a real database connection.
class FakeSupabaseServer {
  // Table storage: table name → list of rows
  final Map<String, List<Map<String, dynamic>>> _tables = {};

  /// Configurable clock for deterministic timestamps in tests.
  /// When set, all upserted rows get this timestamp instead of DateTime.now().
  DateTime? _fixedClock;

  /// Set a fixed clock for deterministic testing. All upserts will use this
  /// timestamp for [updated_at].
  void setClock(DateTime time) {
    _fixedClock = time;
  }

  /// Advance the fixed clock by [duration].
  void advanceClock(Duration duration) {
    if (_fixedClock != null) {
      _fixedClock = _fixedClock!.add(duration);
    }
  }

  DateTime get _now => _fixedClock ?? DateTime.now().toUtc();

  /// Get or create a table's row list.
  List<Map<String, dynamic>> _table(String name) {
    return _tables.putIfAbsent(name, () => []);
  }

  /// Build a [MockClient] that routes all requests through this fake server.
  MockClient get client {
    return MockClient(_handleRequest);
  }

  /// Build a real [SupabaseClient] wired to this fake server via [MockClient].
  /// All HTTP traffic is intercepted; no external connections are made.
  SupabaseClient buildSupabaseClient() {
    return SupabaseClient(
      'http://fake-supabase:9999',
      'fake-anon-key',
      httpClient: client,
    );
  }

  /// Direct access to insert/update test data without going through HTTP.
  void upsertRow(String table, Map<String, dynamic> row, String uniqueColumn) {
    final rows = _table(table);
    final idx = rows.indexWhere(
      (r) => r[uniqueColumn] == row[uniqueColumn],
    );
    if (idx >= 0) {
      rows[idx] = Map<String, dynamic>.from(row);
    } else {
      rows.add(Map<String, dynamic>.from(row));
    }
  }

  /// Manually set table rows (for test setup).
  void setRows(String table, List<Map<String, dynamic>> rows) {
    _tables[table] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ── Request handler ──────────────────────────────────────────────

  Future<Response> _handleRequest(Request request) async {
    final url = request.url;
    final path = url.path; // e.g. "/rest/v1/player_saves"
    final tableName = path.split('/').last;

    // Parse query parameters
    final params = url.queryParameters;

    // Extract filters from query params (column=operator.value format)
    final filters = _parseFilters(params);

    if (request.method == 'GET' || request.method == 'HEAD') {
      return _handleGet(tableName, params, filters, request);
    } else if (request.method == 'POST') {
      final prefer = request.headers['prefer'] ?? '';
      if (prefer.contains('resolution=merge-duplicates')) {
        return _handleUpsert(tableName, request);
      }
      return _handleInsert(tableName, request);
    }

    return Response('{"error":"method not supported"}', 405, request: request);
  }

  // ── Query parsing ────────────────────────────────────────────────

  Map<String, _Filter> _parseFilters(Map<String, String> params) {
    final filters = <String, _Filter>{};
    for (final entry in params.entries) {
      final key = entry.key;
      final value = entry.value;
      // Skip special params
      if (key == 'select' || key == 'order' || key == 'on_conflict' ||
          key == 'limit' || key == 'offset' || key == 'columns') {
        continue;
      }
      // Parse "operator.value" format: e.g. "eq.test-user" or "gt.2024-01-01"
      final dotIndex = value.indexOf('.');
      if (dotIndex >= 0) {
        final op = value.substring(0, dotIndex);
        final val = value.substring(dotIndex + 1);
        filters[key] = _Filter(op, val);
      }
    }
    return filters;
  }

  // ── GET handler ──────────────────────────────────────────────────

  Response _handleGet(
    String tableName,
    Map<String, String> params,
    Map<String, _Filter> filters,
    Request request,
  ) {
    List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(
      _table(tableName).map((r) => Map<String, dynamic>.from(r)),
    );

    // Apply filters
    for (final filter in filters.entries) {
      rows = rows.where((row) {
        final cellValue = row[filter.key];
        return _applyFilter(cellValue, filter.value);
      }).toList();
    }

    // Apply ordering
    final orderParam = params['order'];
    if (orderParam != null) {
      // Format: "column.desc.nullslast"
      final parts = orderParam.split('.');
      final orderCol = parts[0];
      final ascending = parts.length > 1 && parts[1] == 'asc';
      rows.sort((a, b) {
        final aVal = a[orderCol];
        final bVal = b[orderCol];
        if (aVal == null && bVal == null) return 0;
        if (aVal == null) return 1;
        if (bVal == null) return -1;
        final cmp = Comparable.compare(aVal as Comparable, bVal as Comparable);
        return ascending ? cmp : -cmp;
      });
    }

    // Apply select columns (projection)
    final selectParam = params['select'];
    if (selectParam != null && selectParam != '*') {
      final columns = selectParam.split(',').map((c) => c.trim()).toList();
      rows = rows.map((row) {
        final projected = <String, dynamic>{};
        for (final col in columns) {
          if (row.containsKey(col)) {
            projected[col] = row[col];
          }
        }
        return projected;
      }).toList();
    }

    // Handle count (HEAD method or Prefer: count=exact header)
    final countHeader = request.headers['prefer'] ?? '';
    final isCount = countHeader.contains('count=exact') ||
        countHeader.contains('count=planned') ||
        countHeader.contains('count=estimated');

    // For HEAD requests, return empty body with count in Content-Range
    if (request.method == 'HEAD') {
      final count = rows.length;
      return Response(
        '',
        200,
        request: request,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'content-range': '0-${count > 0 ? count - 1 : 0}/$count',
        },
      );
    }

    // Normal GET — always return rows as JSON body
    final body = json.encode(rows);
    final count = rows.length;
    final responseHeaders = <String, String>{
      'content-type': 'application/json; charset=utf-8',
    };
    if (isCount) {
      responseHeaders['content-range'] = '0-${count > 0 ? count - 1 : 0}/$count';
    }
    return Response(
      body,
      200,
      request: request,
      headers: responseHeaders,
    );
  }

  // ── POST / upsert handler ────────────────────────────────────────

  Response _handleUpsert(String tableName, Request request) {
    final decoded = json.decode(request.body);
    final rows = _table(tableName);

    // Determine conflict column from URL query parameter
    final conflictCol = request.url.queryParameters['on_conflict'];

    void insertOrUpdateRow(Map<String, dynamic> rowData) {
      final data = Map<String, dynamic>.from(rowData);
      data['updated_at'] = _now.toIso8601String();
      if (conflictCol != null) {
        final conflictVal = data[conflictCol];
        final idx = rows.indexWhere((r) => r[conflictCol] == conflictVal);
        if (idx >= 0) {
          // Merge: update existing fields, keep others
          rows[idx] = {...rows[idx], ...data};
        } else {
          rows.add(data);
        }
      } else {
        rows.add(data);
      }
    }

    if (decoded is List) {
      for (final item in decoded) {
        insertOrUpdateRow(item as Map<String, dynamic>);
      }
    } else {
      insertOrUpdateRow(decoded as Map<String, dynamic>);
    }

    return Response('', 201, request: request,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  Response _handleInsert(String tableName, Request request) {
    // For bulk inserts (list of rows)
    final decoded = json.decode(request.body);
    final rows = _table(tableName);

    if (decoded is List) {
      for (final item in decoded) {
        final rowData = Map<String, dynamic>.from(item as Map<String, dynamic>);
        rowData['updated_at'] = _now.toIso8601String();
        rows.add(rowData);
      }
    } else {
      final rowData = Map<String, dynamic>.from(decoded as Map<String, dynamic>);
      rowData['updated_at'] = _now.toIso8601String();
      rows.add(rowData);
    }

    return Response('', 201, request: request,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  // ── Filter logic ─────────────────────────────────────────────────

  bool _applyFilter(dynamic cellValue, _Filter filter) {
    final filterVal = filter.value;
    switch (filter.operator) {
      case 'eq':
        return cellValue?.toString() == filterVal;
      case 'gt':
        if (cellValue == null) return false;
        return cellValue.toString().compareTo(filterVal) > 0;
      case 'gte':
        if (cellValue == null) return false;
        return cellValue.toString().compareTo(filterVal) >= 0;
      case 'lt':
        if (cellValue == null) return false;
        return cellValue.toString().compareTo(filterVal) < 0;
      case 'lte':
        if (cellValue == null) return false;
        return cellValue.toString().compareTo(filterVal) <= 0;
      default:
        return true;
    }
  }

  /// Dispose the tables (clean up for next test).
  void reset() {
    _tables.clear();
  }
}

class _Filter {
  final String operator;
  final String value;
  const _Filter(this.operator, this.value);
}

/// ─── Test helpers ──────────────────────────────────────────────────

/// Create a test player with the given HP/EXP values.
PlayerModel testPlayer({int hp = 10000, int exp = 0, Advisor advisor = Advisor.daikokuten}) {
  return PlayerModel(
    hp: hp,
    exp: exp,
    advisor: advisor,
    lastSwitchTimestamp: DateTime.utc(2026, 6, 25),
  );
}

/// Create a test expense entry.
ExpenseEntry testExpense({String id = 'exp-001', int amount = 500, String category = 'food'}) {
  return ExpenseEntry(
    id: id,
    amount: amount,
    category: category,
    date: DateTime.utc(2026, 6, 25, 12, 0),
    note: 'test expense',
    receiptImagePath: null,
  );
}

/// Create a test daily quest state.
DailyQuestState testDailyState({DateTime? date}) {
  return DailyQuestState(
    date: date ?? DateTime.utc(2026, 6, 25),
    quests: [
      DailyQuest(
        id: 'dq-001',
        type: DailyQuestType.spendOnSelf,
        title: 'Spend 1000 on yourself',
        targetValue: 1000,
        currentProgress: 500,
      ),
    ],
  );
}

/// Create test weekly quests.
List<WeeklyQuest> testWeeklyQuests() {
  return [
    WeeklyQuest(
      id: 'wq-001',
      title: 'Keep entertainment under 5000',
      description: 'Limit entertainment spending',
      targetCategory: 'entertainment',
      budgetLimit: 5000,
      currentAvgSpend: 7200,
      difficulty: QuestDifficulty.medium,
      generatedAt: DateTime.utc(2026, 6, 23),
      weekStart: DateTime.utc(2026, 6, 23),
      templateId: 'entertainment_001',
    ),
  ];
}

/// Create a test trial quest.
TrialQuest testTrialQuest() {
  return TrialQuest(
    title: 'Test Trial',
    description: 'A test trial quest',
    suggestedOffering: 3000,
    advisor: Advisor.benzaiten,
    offeringAmount: 2500,
    offeringPurpose: 'Buy tech book',
    offeringNote: 'Test note',
    reflection: 'Learned a lot',
    review: 'Excellent',
    receiptImagePath: null,
    classifiedCategory: 'education',
  );
}

// ═══════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════

void main() {
  late FakeSupabaseServer server;
  late SupabaseClient supabaseClient;
  late CloudSyncService service;
  const testUserId = 'test-user-123';

  setUp(() {
    server = FakeSupabaseServer();
    // Set a deterministic server clock before all test timestamps.
    // Tests use timestamps in the 2026-06-25 08:00-12:00 range.
    // Server clock at 07:00 ensures first-upload tests correctly
    // detect "local is newer" after the first save.
    server.setClock(DateTime.utc(2026, 6, 25, 7, 0, 0));
    supabaseClient = server.buildSupabaseClient();
    service = CloudSyncService(client: supabaseClient);
  });

  tearDown(() async {
    server.reset();
    await supabaseClient.dispose();
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 1: First Sync (no server record exists)
  // ─────────────────────────────────────────────────────────────────

  group('First sync (no server record)', () {
    test('savePlayerState returns FirstSync when no server record exists', () async {
      final player = testPlayer(hp: 10000, exp: 5);

      final result = await service.savePlayerState(
        player,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      expect(result, isA<FirstSync<PlayerModel>>());
    });

    test('saveDailyQuests returns FirstSync for first upload', () async {
      final state = testDailyState();

      final result = await service.saveDailyQuests(
        state,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      expect(result, isA<FirstSync<DailyQuestState>>());
    });

    test('saveTrialQuest returns FirstSync for first upload', () async {
      final quest = testTrialQuest();

      final result = await service.saveTrialQuest(
        quest,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      expect(result, isA<FirstSync<TrialQuest?>>());
    });

    test('saveWeeklyQuests returns FirstSync for first upload', () async {
      final quests = testWeeklyQuests();

      final result = await service.saveWeeklyQuests(
        quests,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      expect(result, isA<FirstSync<List<WeeklyQuest>>>());
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 2: Upload with newer local timestamp
  // ─────────────────────────────────────────────────────────────────

  group('Upload with newer local timestamp', () {
    test('savePlayerState returns Uploaded when local is newer', () async {
      // Pre-seed server data with an older timestamp
      final oldPlayer = testPlayer(hp: 5000, exp: 2);
      server.upsertRow('player_saves', {
        'user_id': testUserId,
        'data': oldPlayer.toJson(),
        'updated_at': DateTime.utc(2026, 6, 25, 8, 0).toIso8601String(),
      }, 'user_id');

      final newPlayer = testPlayer(hp: 20000, exp: 10);

      final result = await service.savePlayerState(
        newPlayer,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0), // newer
      );

      expect(result, isA<Uploaded<PlayerModel>>());

      // Verify the server now has the updated data
      final loaded = await service.loadPlayerState(userId: testUserId);
      expect(loaded, isNotNull);
      expect(loaded!.hp, 20000);
      expect(loaded.exp, 10);
    });

    test('saveDailyQuests returns Uploaded when local is newer', () async {
      final oldState = testDailyState(date: DateTime.utc(2026, 6, 24));
      server.upsertRow('daily_quests', {
        'user_id': testUserId,
        'data': oldState.toJson(),
        'updated_at': DateTime.utc(2026, 6, 25, 8, 0).toIso8601String(),
      }, 'user_id');

      final newState = testDailyState(date: DateTime.utc(2026, 6, 25));

      final result = await service.saveDailyQuests(
        newState,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      expect(result, isA<Uploaded<DailyQuestState>>());

      // Verify load
      final loaded = await service.loadDailyQuests(userId: testUserId);
      expect(loaded, isNotNull);
      expect(loaded!.quests.length, 1);
    });

    test('saveWeeklyQuests returns Uploaded when local is newer', () async {
      final oldQuests = [
        WeeklyQuest(
          id: 'wq-old', title: 'Old Quest', description: 'old',
          targetCategory: 'food', budgetLimit: 1000, currentAvgSpend: 500,
          difficulty: QuestDifficulty.easy,
          generatedAt: DateTime.utc(2026, 6, 20),
          weekStart: DateTime.utc(2026, 6, 20),
          templateId: 'food_001',
        ),
      ];
      server.upsertRow('weekly_quests', {
        'user_id': testUserId,
        'data': oldQuests.map((q) => q.toJson()).toList(),
        'updated_at': DateTime.utc(2026, 6, 25, 8, 0).toIso8601String(),
      }, 'user_id');

      final newQuests = testWeeklyQuests();

      final result = await service.saveWeeklyQuests(
        newQuests,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      expect(result, isA<Uploaded<List<WeeklyQuest>>>());

      final loaded = await service.loadWeeklyQuests(userId: testUserId);
      expect(loaded.length, 1);
      expect(loaded[0].id, 'wq-001');
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 3: Conflict — Server is newer
  // ─────────────────────────────────────────────────────────────────

  group('Conflict resolution — ServerNewer', () {
    test('savePlayerState returns ServerNewer when server is newer', () async {
      // Pre-seed with a NEWER timestamp
      final serverPlayer = testPlayer(hp: 99999, exp: 99);
      server.upsertRow('player_saves', {
        'user_id': testUserId,
        'data': serverPlayer.toJson(),
        'updated_at': DateTime.utc(2026, 6, 25, 12, 0).toIso8601String(),
      }, 'user_id');

      final localPlayer = testPlayer(hp: 100, exp: 0);

      final result = await service.savePlayerState(
        localPlayer,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 8, 0), // older
      );

      expect(result, isA<ServerNewer<PlayerModel>>());
      final serverNewer = result as ServerNewer<PlayerModel>;
      expect(serverNewer.serverData.hp, 99999);
      expect(serverNewer.serverData.exp, 99);

      // Verify local was NOT uploaded (server data preserved)
      final loaded = await service.loadPlayerState(userId: testUserId);
      expect(loaded!.hp, 99999);
    });

    test('savePlayerState returns ServerNewer when timestamps are equal', () async {
      final sameTime = DateTime.utc(2026, 6, 25, 12, 0);
      final serverPlayer = testPlayer(hp: 50000, exp: 25);
      server.upsertRow('player_saves', {
        'user_id': testUserId,
        'data': serverPlayer.toJson(),
        'updated_at': sameTime.toIso8601String(),
      }, 'user_id');

      final localPlayer = testPlayer(hp: 10000, exp: 0);

      final result = await service.savePlayerState(
        localPlayer,
        userId: testUserId,
        localUpdatedAt: sameTime,
      );

      // Equal timestamps resolve to useServer (safe side)
      expect(result, isA<ServerNewer<PlayerModel>>());
    });

    test('saveDailyQuests returns ServerNewer when server data is newer', () async {
      final serverState = testDailyState(date: DateTime.utc(2026, 6, 26));
      server.upsertRow('daily_quests', {
        'user_id': testUserId,
        'data': serverState.toJson(),
        'updated_at': DateTime.utc(2026, 6, 25, 12, 0).toIso8601String(),
      }, 'user_id');

      final localState = testDailyState(date: DateTime.utc(2026, 6, 24));

      final result = await service.saveDailyQuests(
        localState,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 8, 0),
      );

      expect(result, isA<ServerNewer<DailyQuestState>>());
      final serverNewer = result as ServerNewer<DailyQuestState>;
      expect(serverNewer.serverData.date, DateTime.utc(2026, 6, 26));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 4: downloadAll restore flow
  // ─────────────────────────────────────────────────────────────────

  group('downloadAll restore flow', () {
    test('downloadAll returns empty data when server has nothing', () async {
      final result = await service.downloadAll(userId: testUserId);

      expect(result['player_save'], isNull);
      expect(result['expense_entries'], isEmpty);
      expect(result['daily_quests'], isNull);
      expect(result['weekly_quests'], isEmpty);
      expect(result['trial_quest'], isNull);
    });

    test('downloadAll returns all data after uploads', () async {
      // Upload player
      final player = testPlayer(hp: 12000, exp: 7);
      await service.savePlayerState(
        player,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      // Upload expenses
      await service.saveExpenseEntries([
        testExpense(id: 'exp-a', amount: 300, category: 'food'),
        testExpense(id: 'exp-b', amount: 1500, category: 'transport'),
      ], userId: testUserId);

      // Upload daily quests
      final daily = testDailyState();
      await service.saveDailyQuests(
        daily,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      // Upload weekly quests
      final weekly = testWeeklyQuests();
      await service.saveWeeklyQuests(
        weekly,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      // Upload trial quest
      final trial = testTrialQuest();
      await service.saveTrialQuest(
        trial,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      // Now download all
      final result = await service.downloadAll(userId: testUserId);

      // Verify player
      expect(result['player_save'], isNotNull);
      final playerJson = result['player_save'] as Map<String, dynamic>;
      expect(playerJson['hp'], 12000);
      expect(playerJson['exp'], 7);

      // Verify expenses
      final expenseList = result['expense_entries'] as List<dynamic>;
      expect(expenseList.length, 2);

      // Verify daily quests
      expect(result['daily_quests'], isNotNull);

      // Verify weekly quests
      final weeklyList = result['weekly_quests'] as List<dynamic>;
      expect(weeklyList.length, 1);
      expect(weeklyList[0]['id'], 'wq-001');

      // Verify trial quest
      expect(result['trial_quest'], isNotNull);
      expect(result['trial_quest']['title'], 'Test Trial');
    });

    test('downloadAll after partial data upload', () async {
      // Only upload player and daily quests
      final player = testPlayer(hp: 8000, exp: 3);
      await service.savePlayerState(
        player,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      final daily = testDailyState();
      await service.saveDailyQuests(
        daily,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );

      final result = await service.downloadAll(userId: testUserId);

      expect(result['player_save'], isNotNull);
      expect(result['daily_quests'], isNotNull);
      expect(result['expense_entries'], isEmpty);
      expect(result['weekly_quests'], isEmpty);
      expect(result['trial_quest'], isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 5: End-to-end sync lifecycle
  // ─────────────────────────────────────────────────────────────────

  group('End-to-end sync lifecycle', () {
    test('full lifecycle: first sync → update → conflict → restore', () async {
      // Use a fixed clock so server timestamps are deterministic
      server.setClock(DateTime.utc(2026, 6, 25, 10, 0));

      // Phase 1: First sync — upload initial data
      // Server has no record, so getPlayerUpdatedAt returns null → FirstSync
      final initialPlayer = testPlayer(hp: 5000, exp: 1);
      final result1 = await service.savePlayerState(
        initialPlayer,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0),
      );
      expect(result1, isA<FirstSync<PlayerModel>>());
      // After upsert, server updated_at = 10:00 (our fixed clock)

      // Verify data is on server
      var loaded = await service.loadPlayerState(userId: testUserId);
      expect(loaded!.hp, 5000);

      // Phase 2: Update with newer local timestamp — should upload
      // Advance clock and use a newer local timestamp
      server.advanceClock(const Duration(minutes: 5));
      // Server updated_at is now 10:05, but local says 11:00 → upload
      final updatedPlayer = testPlayer(hp: 15000, exp: 5);
      final result2 = await service.savePlayerState(
        updatedPlayer,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 11, 0), // newer than server's 10:00
      );
      expect(result2, isA<Uploaded<PlayerModel>>());
      // After this upsert, server updated_at becomes 10:05

      // Verify update took effect
      loaded = await service.loadPlayerState(userId: testUserId);
      expect(loaded!.hp, 15000);

      // Phase 3: Try to upload with older timestamp — conflict!
      // Server updated_at is 10:05, local says 9:00 → server newer
      server.advanceClock(const Duration(minutes: 5)); // server clock now 10:10
      final stalePlayer = testPlayer(hp: 999, exp: 0);
      final result3 = await service.savePlayerState(
        stalePlayer,
        userId: testUserId,
        localUpdatedAt: DateTime.utc(2026, 6, 25, 9, 0), // older than server
      );
      expect(result3, isA<ServerNewer<PlayerModel>>());
      final conflictResult = result3 as ServerNewer<PlayerModel>;
      expect(conflictResult.serverData.hp, 15000); // server version preserved

      // Phase 4: Restore/download — verify all data intact
      final downloadResult = await service.downloadAll(userId: testUserId);
      final playerJson = downloadResult['player_save'] as Map<String, dynamic>;
      expect(playerJson['hp'], 15000);
      expect(playerJson['exp'], 5);
    });

    test('multiple data types sync independently', () async {
      server.setClock(DateTime.utc(2026, 6, 25, 10, 0));

      // Seed: upload player first
      final player = testPlayer(hp: 10000, exp: 10);
      await service.savePlayerState(player, userId: testUserId,
          localUpdatedAt: DateTime.utc(2026, 6, 25, 10, 0));

      // Upload expenses (simple upsert, no conflict resolution)
      await service.saveExpenseEntries(
        [testExpense(id: 'ind-1', amount: 100)],
        userId: testUserId,
      );

      // Upload daily with older timestamp
      server.advanceClock(const Duration(minutes: 1)); // server now 10:01
      final oldDaily = testDailyState(date: DateTime.utc(2026, 6, 24));
      await service.saveDailyQuests(oldDaily, userId: testUserId,
          localUpdatedAt: DateTime.utc(2026, 6, 25, 8, 0));
      // Server updated_at for daily_quests is now 10:01

      // Now try to upload daily with newer local timestamp
      server.advanceClock(const Duration(minutes: 1)); // server now 10:02
      final newDaily = testDailyState(date: DateTime.utc(2026, 6, 26));
      final result = await service.saveDailyQuests(newDaily, userId: testUserId,
          localUpdatedAt: DateTime.utc(2026, 6, 25, 12, 0)); // newer than 10:01
      expect(result, isA<Uploaded<DailyQuestState>>());

      // Verify all data is correct
      final all = await service.downloadAll(userId: testUserId);
      expect((all['player_save'] as Map)['hp'], 10000);
      expect((all['expense_entries'] as List).length, 1);
      expect((all['daily_quests'] as Map)['date'], contains('2026-06-26'));
    });

    test('loadPlayerState returns null for unknown user', () async {
      final result = await service.loadPlayerState(userId: 'nonexistent-user');
      expect(result, isNull);
    });

    test('saveExpenseEntries with empty list does nothing', () async {
      await service.saveExpenseEntries([], userId: testUserId);
      // Should not throw, and count should be 0
      final count = await service.getExpenseCount(userId: testUserId);
      expect(count, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 6: Expense entries CRUD via sync
  // ─────────────────────────────────────────────────────────────────

  group('Expense entries sync', () {
    test('save and load expense entries', () async {
      final entries = [
        testExpense(id: 'e-1', amount: 200, category: 'food'),
        testExpense(id: 'e-2', amount: 800, category: 'books'),
      ];
      await service.saveExpenseEntries(entries, userId: testUserId);

      final loaded = await service.loadExpenseEntries(userId: testUserId);
      expect(loaded.length, 2);
      expect(loaded.map((e) => e.id).toSet(), containsAll(['e-1', 'e-2']));
    });

    test('getExpenseCount returns correct count', () async {
      expect(await service.getExpenseCount(userId: testUserId), 0);

      await service.saveExpenseEntries(
        [testExpense(id: 'c-1', amount: 100)],
        userId: testUserId,
      );
      expect(await service.getExpenseCount(userId: testUserId), 1);

      await service.saveExpenseEntries(
        [testExpense(id: 'c-2', amount: 200), testExpense(id: 'c-3', amount: 300)],
        userId: testUserId,
      );
      expect(await service.getExpenseCount(userId: testUserId), 3);
    });

    test('loadExpenseEntries with lastSyncAt filter', () async {
      // Pre-seed with entries at different timestamps
      server.setRows('expense_entries', [
        {
          'id': 'old-1', 'user_id': testUserId, 'amount': 50, 'category': 'food',
          'date': '2026-06-24T00:00:00.000Z', 'note': 'old',
          'receipt_image_path': null,
          'updated_at': '2026-06-24T12:00:00.000Z',
        },
        {
          'id': 'new-1', 'user_id': testUserId, 'amount': 150, 'category': 'transport',
          'date': '2026-06-25T00:00:00.000Z', 'note': 'new',
          'receipt_image_path': null,
          'updated_at': '2026-06-25T12:00:00.000Z',
        },
      ]);

      final all = await service.loadExpenseEntries(userId: testUserId);
      expect(all.length, 2);

      final recent = await service.loadExpenseEntries(
        userId: testUserId,
        lastSyncAt: DateTime.utc(2026, 6, 25, 0, 0),
      );
      expect(recent.length, 1);
      expect(recent[0].id, 'new-1');
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 7: SaveResult type hierarchy and pattern matching
  // ─────────────────────────────────────────────────────────────────

  group('SaveResult type hierarchy', () {
    test('Uploaded is a SaveResult', () {
      expect(const Uploaded<PlayerModel>(), isA<SaveResult<PlayerModel>>());
    });

    test('ServerNewer carries server data', () {
      final p = PlayerModel(hp: 42, exp: 7);
      final result = ServerNewer<PlayerModel>(p);
      expect(result.serverData, same(p));
    });

    test('FirstSync is a SaveResult', () {
      expect(const FirstSync<PlayerModel>(), isA<SaveResult<PlayerModel>>());
    });

    test('pattern matching on SaveResult works', () {
      final SaveResult<PlayerModel> result = ServerNewer<PlayerModel>(
        PlayerModel(hp: 100, exp: 0));
      
      final label = switch (result) {
        Uploaded() => 'uploaded',
        ServerNewer(:final serverData) => 'conflict_hp_${serverData.hp}',
        FirstSync() => 'first_sync',
      };
      expect(label, 'conflict_hp_100');
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 8: ConflictDecision unit tests (static method)
  // ─────────────────────────────────────────────────────────────────

  group('ConflictDecision', () {
    test('null server = firstSync', () {
      expect(
        CloudSyncService.resolveConflict(DateTime.utc(2026, 6, 25), null),
        ConflictDecision.firstSync,
      );
    });

    test('local newer = upload', () {
      expect(
        CloudSyncService.resolveConflict(
          DateTime.utc(2026, 6, 25, 12, 0),
          DateTime.utc(2026, 6, 25, 11, 0),
        ),
        ConflictDecision.upload,
      );
    });

    test('server newer = useServer', () {
      expect(
        CloudSyncService.resolveConflict(
          DateTime.utc(2026, 6, 25, 11, 0),
          DateTime.utc(2026, 6, 25, 12, 0),
        ),
        ConflictDecision.useServer,
      );
    });

    test('equal timestamps = useServer', () {
      final t = DateTime.utc(2026, 6, 25, 12, 0);
      expect(
        CloudSyncService.resolveConflict(t, t),
        ConflictDecision.useServer,
      );
    });
  });
}

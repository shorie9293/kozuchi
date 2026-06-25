import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';

// ─── 競合解決の結果型 ──────────────────────────────────────────

/// Result of server save with conflict resolution (last-write-wins).
sealed class SaveResult<T> {
  const SaveResult();
}

/// Local data was newer, uploaded to server.
class Uploaded<T> extends SaveResult<T> {
  const Uploaded();
}

/// Server data was newer, upload skipped. Use [serverData] as source of truth.
class ServerNewer<T> extends SaveResult<T> {
  final T serverData;
  const ServerNewer(this.serverData);
}

/// No server record exists (first sync). Upload was performed.
class FirstSync<T> extends SaveResult<T> {
  const FirstSync();
}

// ─── 競合解決の判断用列挙型 ──────────────────────────────────

/// Internal conflict resolution decision.
enum ConflictDecision { upload, useServer, firstSync }

/// Cloud sync service using Supabase for player data persistence.
///
/// All operations are scoped to the authenticated user via RLS.
class CloudSyncService {
  final SupabaseClient _client;

  CloudSyncService({required SupabaseClient client}) : _client = client;

  // ─── プレイヤー状態（player_saves） ─────────────────────────────

  /// Save player state with conflict resolution (last-write-wins).
  ///
  /// [localUpdatedAt] is the local modification timestamp.
  /// Compares against server's updated_at: if local is newer, uploads.
  /// If server is newer, skips upload and returns server version.
  /// If no server record exists, performs first sync.
  Future<SaveResult<PlayerModel>> savePlayerState(
    PlayerModel player, {
    required String userId,
    required DateTime localUpdatedAt,
    int dataVersion = 1,
  }) async {
    final serverUpdatedAt = await getPlayerUpdatedAt(userId: userId);
    final decision = resolveConflict(localUpdatedAt, serverUpdatedAt);

    switch (decision) {
      case ConflictDecision.firstSync:
        await _doUpsert(userId, player, dataVersion);
        return const FirstSync<PlayerModel>();

      case ConflictDecision.upload:
        await _doUpsert(userId, player, dataVersion);
        return const Uploaded<PlayerModel>();

      case ConflictDecision.useServer:
        final serverPlayer = await loadPlayerState(userId: userId);
        return ServerNewer<PlayerModel>(serverPlayer!);
    }
  }

  Future<void> _doUpsert(
    String userId,
    PlayerModel player,
    int dataVersion,
  ) async {
    await _client.from('player_saves').upsert(
      {
        'user_id': userId,
        'data': player.toJson(),
        'data_version': dataVersion,
      },
      onConflict: 'user_id',
    );
  }

  /// Load player state from server.
  ///
  /// Returns null if no saved data exists.
  Future<PlayerModel?> loadPlayerState({
    required String userId,
  }) async {
    final response = await _client
        .from('player_saves')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    return PlayerModel.fromJson(data);
  }

  /// Get player state last-updated timestamp from server.
  ///
  /// Returns null if no record exists. Used for conflict resolution.
  Future<DateTime?> getPlayerUpdatedAt({
    required String userId,
  }) async {
    final response = await _client
        .from('player_saves')
        .select('updated_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    final updatedAt = response['updated_at'] as String?;
    if (updatedAt == null) return null;
    return DateTime.tryParse(updatedAt);
  }

  // ─── 支出エントリ（expense_entries） ─────────────────────────────

  /// Save expense entries (upsert).
  ///
  /// Same ID entries are overwritten, new ones inserted.
  Future<void> saveExpenseEntries(
    List<ExpenseEntry> entries, {
    required String userId,
  }) async {
    if (entries.isEmpty) return;

    final rows = entries.map((e) {
      return {
        'id': e.id,
        'user_id': userId,
        'amount': e.amount,
        'category': e.category,
        'date': e.date.toUtc().toIso8601String(),
        'note': e.note,
        'receipt_image_path': e.receiptImagePath,
      };
    }).toList();

    await _client.from('expense_entries').upsert(rows);
  }

  /// Load expense entries (all or diff since last sync).
  Future<List<ExpenseEntry>> loadExpenseEntries({
    required String userId,
    DateTime? lastSyncAt,
  }) async {
    var filter = _client
        .from('expense_entries')
        .select()
        .eq('user_id', userId);

    if (lastSyncAt != null) {
      filter = filter.gt('updated_at', lastSyncAt.toUtc().toIso8601String());
    }

    final response = await filter.order('date', ascending: false);

    return (response as List<dynamic>)
        .map((row) => ExpenseEntry.fromJson(_rowToExpenseJson(row)))
        .toList();
  }

  /// Get total expense entry count (for debugging).
  Future<int> getExpenseCount({required String userId}) async {
    final response = await _client
        .from('expense_entries')
        .select('id')
        .eq('user_id', userId)
        .count(CountOption.exact);

    return response.count ?? 0;
  }

  // ─── デイリークエスト（daily_quests） ────────────────────────────

  /// Save daily quest state (upsert).
  Future<void> saveDailyQuests(
    DailyQuestState state, {
    required String userId,
  }) async {
    await _client.from('daily_quests').upsert(
      {
        'user_id': userId,
        'data': state.toJson(),
      },
      onConflict: 'user_id',
    );
  }

  /// Load daily quest state.
  Future<DailyQuestState?> loadDailyQuests({
    required String userId,
  }) async {
    final response = await _client
        .from('daily_quests')
        .select('data')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    return DailyQuestState.fromJson(data);
  }

  // ─── 週間クエスト（weekly_quests） ──────────────────────────────

  /// Save weekly quest list (upsert).
  Future<void> saveWeeklyQuests(
    List<WeeklyQuest> quests, {
    required String userId,
  }) async {
    final data = quests.map((q) => q.toJson()).toList();
    await _client.from('weekly_quests').upsert(
      {
        'user_id': userId,
        'data': data,
      },
      onConflict: 'user_id',
    );
  }

  /// Load weekly quest list.
  Future<List<WeeklyQuest>> loadWeeklyQuests({
    required String userId,
  }) async {
    final response = await _client
        .from('weekly_quests')
        .select('data')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return [];
    final rawData = response['data'];
    if (rawData == null) return [];

    final list = rawData as List<dynamic>;
    return list
        .map((e) => WeeklyQuest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── 試練クエスト（trial_quest） ────────────────────────────────

  /// Save trial quest (upsert).
  Future<void> saveTrialQuest(
    TrialQuest? quest, {
    required String userId,
  }) async {
    await _client.from('trial_quest').upsert(
      {
        'user_id': userId,
        'data': quest?.toJson(),
      },
      onConflict: 'user_id',
    );
  }

  /// Load trial quest.
  Future<TrialQuest?> loadTrialQuest({
    required String userId,
  }) async {
    final response = await _client
        .from('trial_quest')
        .select('data')
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    return TrialQuest.fromJson(data);
  }

  // ─── 全データ一括操作 ──────────────────────────────────────────

  /// Download all data from server (for device migration/restore).
  Future<Map<String, dynamic>> downloadAll({required String userId}) async {
    final results = <String, dynamic>{};

    final player = await loadPlayerState(userId: userId);
    results['player_save'] = player?.toJson();

    final expenses = await loadExpenseEntries(userId: userId);
    results['expense_entries'] = expenses.map((e) => e.toJson()).toList();

    final daily = await loadDailyQuests(userId: userId);
    results['daily_quests'] = daily?.toJson();

    final weekly = await loadWeeklyQuests(userId: userId);
    results['weekly_quests'] = weekly.map((e) => e.toJson()).toList();

    final trial = await loadTrialQuest(userId: userId);
    results['trial_quest'] = trial?.toJson();

    return results;
  }

  // ─── ヘルパー ──────────────────────────────────────────────────

  /// Resolve conflict by comparing local and server timestamps.
  ///
  /// Returns [ConflictDecision.upload] if local is newer,
  /// [ConflictDecision.useServer] if server is newer or same time,
  /// [ConflictDecision.firstSync] if no server record exists.
  static ConflictDecision resolveConflict(
    DateTime localUpdatedAt,
    DateTime? serverUpdatedAt,
  ) {
    if (serverUpdatedAt == null) return ConflictDecision.firstSync;
    return localUpdatedAt.isAfter(serverUpdatedAt)
        ? ConflictDecision.upload
        : ConflictDecision.useServer;
  }

  /// Convert Supabase row data to ExpenseEntry JSON format.
  Map<String, dynamic> _rowToExpenseJson(dynamic row) {
    final r = row as Map<String, dynamic>;
    return {
      'id': r['id'] as String,
      'amount': r['amount'] as int,
      'category': r['category'] as String,
      'date': r['date'] as String,
      'note': r['note'] as String?,
      'receiptImagePath': r['receipt_image_path'] as String?,
    };
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/services/expense_cloud_store.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';

// ─── Conflict resolution result types ──────────────────────────

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

// ─── Internal conflict decision ───────────────────────────────

enum ConflictDecision { upload, useServer, firstSync }

/// Cloud sync service using Supabase for player data persistence.
///
/// [ExpenseCloudStore] を実装し、支出明細の保存/取得を提供する。
class CloudSyncService implements ExpenseCloudStore {
  final SupabaseClient _client;

  CloudSyncService({required SupabaseClient client}) : _client = client;

  // ─── Player state (player_saves) ─────────────────────────────

  /// Save player state with conflict resolution (last-write-wins).
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

  Future<void> _doUpsert(String userId, PlayerModel player, int dataVersion) async {
    await _client.from('player_saves').upsert(
      {'user_id': userId, 'data': player.toJson(), 'data_version': dataVersion},
      onConflict: 'user_id',
    );
  }

  Future<PlayerModel?> loadPlayerState({required String userId}) async {
    final response = await _client.from('player_saves').select()
        .eq('user_id', userId).maybeSingle();
    if (response == null) return null;
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return PlayerModel.fromJson(data);
  }

  Future<DateTime?> getPlayerUpdatedAt({required String userId}) async {
    final response = await _client.from('player_saves').select('updated_at')
        .eq('user_id', userId).maybeSingle();
    if (response == null) return null;
    final updatedAt = response['updated_at'] as String?;
    if (updatedAt == null) return null;
    return DateTime.tryParse(updatedAt);
  }

  // ─── Expense entries (expense_entries) ───────────────────────

  /// Save expense entries (upsert by UUID). ID-based merge per spec 5.2.
  Future<void> saveExpenseEntries(
    List<ExpenseEntry> entries, {required String userId}) async {
    if (entries.isEmpty) return;
    final rows = entries.map((e) => {
      'id': e.id, 'user_id': userId, 'amount': e.amount,
      'category': e.category, 'date': e.date.toUtc().toIso8601String(),
      'note': e.note, 'receipt_image_path': e.receiptImagePath,
    }).toList();
    await _client.from('expense_entries').upsert(rows);
  }

  Future<List<ExpenseEntry>> loadExpenseEntries({
    required String userId, DateTime? lastSyncAt}) async {
    var filter = _client.from('expense_entries').select().eq('user_id', userId);
    if (lastSyncAt != null) {
      filter = filter.gt('updated_at', lastSyncAt.toUtc().toIso8601String());
    }
    final response = await filter.order('date', ascending: false);
    return (response as List<dynamic>)
        .map((row) => ExpenseEntry.fromJson(_rowToExpenseJson(row))).toList();
  }

  Future<int> getExpenseCount({required String userId}) async {
    final response = await _client.from('expense_entries').select('id')
        .eq('user_id', userId).count(CountOption.exact);
    return response.count;
  }

  // ─── Daily quests (daily_quests) ─────────────────────────────

  /// Save daily quest state with conflict resolution.
  Future<SaveResult<DailyQuestState>> saveDailyQuests(
    DailyQuestState state, {
    required String userId,
    required DateTime localUpdatedAt,
  }) async {
    final serverUpdatedAt = await _getUpdatedAt(
      table: 'daily_quests', userId: userId);
    final decision = resolveConflict(localUpdatedAt, serverUpdatedAt);

    switch (decision) {
      case ConflictDecision.firstSync:
        await _client.from('daily_quests').upsert(
          {'user_id': userId, 'data': state.toJson()}, onConflict: 'user_id');
        return const FirstSync<DailyQuestState>();
      case ConflictDecision.upload:
        await _client.from('daily_quests').upsert(
          {'user_id': userId, 'data': state.toJson()}, onConflict: 'user_id');
        return const Uploaded<DailyQuestState>();
      case ConflictDecision.useServer:
        final serverState = await loadDailyQuests(userId: userId);
        return ServerNewer<DailyQuestState>(serverState!);
    }
  }

  Future<DailyQuestState?> loadDailyQuests({required String userId}) async {
    final response = await _client.from('daily_quests').select('data')
        .eq('user_id', userId).maybeSingle();
    if (response == null) return null;
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return DailyQuestState.fromJson(data);
  }

  // ─── Weekly quests (weekly_quests) ───────────────────────────

  /// Save weekly quest list with conflict resolution.
  Future<SaveResult<List<WeeklyQuest>>> saveWeeklyQuests(
    List<WeeklyQuest> quests, {
    required String userId,
    required DateTime localUpdatedAt,
  }) async {
    final serverUpdatedAt = await _getUpdatedAt(
      table: 'weekly_quests', userId: userId);
    final decision = resolveConflict(localUpdatedAt, serverUpdatedAt);

    switch (decision) {
      case ConflictDecision.firstSync:
        final data = quests.map((q) => q.toJson()).toList();
        await _client.from('weekly_quests').upsert(
          {'user_id': userId, 'data': data}, onConflict: 'user_id');
        return const FirstSync<List<WeeklyQuest>>();
      case ConflictDecision.upload:
        final data = quests.map((q) => q.toJson()).toList();
        await _client.from('weekly_quests').upsert(
          {'user_id': userId, 'data': data}, onConflict: 'user_id');
        return const Uploaded<List<WeeklyQuest>>();
      case ConflictDecision.useServer:
        final serverQuests = await loadWeeklyQuests(userId: userId);
        return ServerNewer<List<WeeklyQuest>>(serverQuests);
    }
  }

  Future<List<WeeklyQuest>> loadWeeklyQuests({required String userId}) async {
    final response = await _client.from('weekly_quests').select('data')
        .eq('user_id', userId).maybeSingle();
    if (response == null) return [];
    final rawData = response['data'];
    if (rawData == null) return [];
    final list = rawData as List<dynamic>;
    return list.map((e) => WeeklyQuest.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Trial quest (trial_quest) ───────────────────────────────

  /// Save trial quest with conflict resolution.
  Future<SaveResult<TrialQuest?>> saveTrialQuest(
    TrialQuest? quest, {
    required String userId,
    required DateTime localUpdatedAt,
  }) async {
    final serverUpdatedAt = await _getUpdatedAt(
      table: 'trial_quest', userId: userId);
    final decision = resolveConflict(localUpdatedAt, serverUpdatedAt);

    switch (decision) {
      case ConflictDecision.firstSync:
        await _client.from('trial_quest').upsert(
          {'user_id': userId, 'data': quest?.toJson()}, onConflict: 'user_id');
        return const FirstSync<TrialQuest?>();
      case ConflictDecision.upload:
        await _client.from('trial_quest').upsert(
          {'user_id': userId, 'data': quest?.toJson()}, onConflict: 'user_id');
        return const Uploaded<TrialQuest?>();
      case ConflictDecision.useServer:
        final serverQuest = await loadTrialQuest(userId: userId);
        return ServerNewer<TrialQuest?>(serverQuest);
    }
  }

  Future<TrialQuest?> loadTrialQuest({required String userId}) async {
    final response = await _client.from('trial_quest').select('data')
        .eq('user_id', userId).maybeSingle();
    if (response == null) return null;
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return TrialQuest.fromJson(data);
  }

  // ─── Bulk operations ─────────────────────────────────────────

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

  // ─── Helpers ─────────────────────────────────────────────────

  /// Compare local and server timestamps for last-write-wins conflict resolution.
  static ConflictDecision resolveConflict(
    DateTime localUpdatedAt, DateTime? serverUpdatedAt) {
    if (serverUpdatedAt == null) return ConflictDecision.firstSync;
    return localUpdatedAt.isAfter(serverUpdatedAt)
        ? ConflictDecision.upload : ConflictDecision.useServer;
  }

  /// Generic updated_at fetcher for any user-scoped table.
  Future<DateTime?> _getUpdatedAt({
    required String table, required String userId}) async {
    final response = await _client.from(table).select('updated_at')
        .eq('user_id', userId).maybeSingle();
    if (response == null) return null;
    final updatedAt = response['updated_at'] as String?;
    if (updatedAt == null) return null;
    return DateTime.tryParse(updatedAt);
  }

  /// Convert Supabase row to ExpenseEntry JSON format.
  Map<String, dynamic> _rowToExpenseJson(dynamic row) {
    final r = row as Map<String, dynamic>;
    return {
      'id': r['id'] as String, 'amount': r['amount'] as int,
      'category': r['category'] as String, 'date': r['date'] as String,
      'note': r['note'] as String?,
      'receiptImagePath': r['receipt_image_path'] as String?,
    };
  }
}

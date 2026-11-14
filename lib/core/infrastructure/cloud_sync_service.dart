import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/core/infrastructure/expense_entries_load_result.dart';
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
class CloudSyncService
    implements ExpenseCloudStore, ExpenseEntriesResultSource {
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

  /// 支出明細を取得する（date 降順）。
  ///
  /// 破損行があっても例外を投げず、読めた行だけを返す。
  /// 読み飛ばし件数・照合可否が要る呼出側は
  /// [loadExpenseEntriesResult] を使う。
  Future<List<ExpenseEntry>> loadExpenseEntries({
    required String userId, DateTime? lastSyncAt}) async {
    final result = await loadExpenseEntriesResult(
      userId: userId, lastSyncAt: lastSyncAt);
    return result.entries;
  }

  @override
  Future<ExpenseEntriesLoadResult> loadExpenseEntriesResult({
    required String userId, DateTime? lastSyncAt}) async {
    var filter = _client.from('expense_entries').select().eq('user_id', userId);
    if (lastSyncAt != null) {
      filter = filter.gt('updated_at', lastSyncAt.toUtc().toIso8601String());
    }
    dynamic response;
    try {
      response = await filter.order('date', ascending: false);
    } on TypeError {
      // postgrest は応答本文を List として復号できないと、この層へ届く前に
      // TypeError で落ちる。型不整合な応答＝「照合そのものができない」。
      return const ExpenseEntriesLoadResult(
        entries: [], skippedCount: 0, canVerify: false);
    }
    // 応答がリストでなければ「照合そのものができない」。ここで throw しない。
    if (response is! List) {
      return const ExpenseEntriesLoadResult(
        entries: [], skippedCount: 0, canVerify: false);
    }
    // 1行の破損で全件を失わない（破損行は読み飛ばして数える）。
    // 日時は tryFromJson が必ずローカル瞬間へ正規化する。
    final restored = <ExpenseEntry>[];
    var skipped = 0;
    for (final row in response) {
      final json = tryRowToExpenseJson(row);
      final entry = json == null ? null : ExpenseEntry.tryFromJson(json);
      if (entry == null) {
        skipped++;
      } else {
        restored.add(entry);
      }
    }
    return ExpenseEntriesLoadResult(
      entries: restored, skippedCount: skipped, canVerify: true);
  }

  Future<int> getExpenseCount({required String userId}) async {
    final response = await _client.from('expense_entries').select('id')
        .eq('user_id', userId).count(CountOption.exact);
    return response.count;
  }

  /// 指定IDの支出明細を削除する（冪等）。
  Future<void> deleteExpenseEntry(String id, {required String userId}) async {
    await _client.from('expense_entries')
        .delete().eq('id', id).eq('user_id', userId);
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
    final expenses = await loadExpenseEntriesResult(userId: userId);
    results['expense_entries'] =
        expenses.entries.map((e) => e.toJson()).toList();
    // 読み飛ばした破損行の件数（後方互換: 既存キーは不変のまま追加）。
    results['expense_entries_skipped'] = expenses.skippedCount;
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

  /// Supabase の行を ExpenseEntry の JSON 形式へ写す。**throw しない**。
  ///
  /// 型が合わない行は `null`（呼出側は読み飛ばして件数を数える）。
  /// 意味の検証（amount <= 0 等）はここでは行わない — 型だけを見て、
  /// 意味は [ExpenseEntry.tryFromJson] に一任する（判定の二重定義を避ける）。
  static Map<String, dynamic>? tryRowToExpenseJson(Object? row) {
    if (row is! Map) return null;
    final id = row['id'];
    final amount = row['amount'];
    final category = row['category'];
    final date = row['date'];
    if (id is! String || amount is! int || category is! String || date is! String) {
      return null;
    }
    final note = row['note'];
    final receipt = row['receipt_image_path'];
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'date': date,
      'note': note is String ? note : null,
      'receiptImagePath': receipt is String ? receipt : null,
    };
  }
}

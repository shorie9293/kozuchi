import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/models/expense_entry.dart';
import 'package:kozuchi/domain/models/daily_quest.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';

/// クラウド同期サービス
///
/// Supabase を介してプレイヤーデータの保存・復元を行う。
/// 匿名認証されたユーザーID をキーに、全テーブルで RLS によるデータ隔離が強制される。
///
/// 使用例:
/// ```dart
/// final syncService = CloudSyncService(client: Supabase.instance.client);
/// await syncService.savePlayerState(player, userId: userId);
/// final player = await syncService.loadPlayerState(userId: userId);
/// ```
class CloudSyncService {
  final SupabaseClient _client;

  CloudSyncService({required SupabaseClient client}) : _client = client;

  // ─── プレイヤー状態（player_saves） ─────────────────────────────

  /// プレイヤー状態をサーバーに保存（upsert）
  ///
  /// [player] の toJson() を data カラムに格納し、
  /// user_id の重複時は上書きする。
  Future<void> savePlayerState(
    PlayerModel player, {
    required String userId,
    int dataVersion = 1,
  }) async {
    await _client.from('player_saves').upsert(
      {
        'user_id': userId,
        'data': player.toJson(),
        'data_version': dataVersion,
      },
      onConflict: 'user_id',
    );
  }

  /// プレイヤー状態をサーバーから取得
  ///
  /// 保存データがない場合は null を返す。
  /// 呼び出し側は null の場合にデフォルトプレイヤーを使用すべき。
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

  /// プレイヤー状態がサーバーで更新された日時を取得
  ///
  /// 競合解決のための比較用。保存データがない場合は null。
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

  /// 支出エントリを一括保存（upsert）
  ///
  /// 同じ ID のエントリは上書き、新規は追加。
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

  /// 支出エントリを取得（全件または最終同期以降の差分）
  ///
  /// [lastSyncAt] を指定すると、その日時以降に更新されたエントリのみ返す。
  Future<List<ExpenseEntry>> loadExpenseEntries({
    required String userId,
    DateTime? lastSyncAt,
  }) async {
    // gt フィルタは order より先に適用する必要がある
    // （order() の戻り値が PostgrestTransformBuilder に狭まるため）
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

  /// 支出エントリの全件数を取得（デバッグ・確認用）
  Future<int> getExpenseCount({required String userId}) async {
    final response = await _client
        .from('expense_entries')
        .select('id')
        .eq('user_id', userId)
        .count(CountOption.exact);

    return response.count ?? 0; // ignore: dead_null_aware_expression
  }

  // ─── デイリークエスト（daily_quests） ────────────────────────────

  /// デイリークエスト状態を保存（upsert）
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

  /// デイリークエスト状態を取得
  ///
  /// 保存データがない場合は null。
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

  /// 週間クエスト一覧を保存（upsert）
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

  /// 週間クエスト一覧を取得
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

  /// 試練クエストを保存（upsert）
  ///
  /// [quest] が null の場合はアクティブな試練がない状態として保存。
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

  /// 試練クエストを取得
  ///
  /// アクティブな試練がない場合は null。
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

  /// 全データをサーバーから一括取得（端末変更・復元用）
  ///
  /// 各テーブルから個別に取得するため、RPC 関数が使えない場合の
  /// フォールバック実装。RLS によりユーザー自身のデータのみ返る。
  Future<Map<String, dynamic>> downloadAll({required String userId}) async {
    final results = <String, dynamic>{};

    // プレイヤー状態
    final player = await loadPlayerState(userId: userId);
    results['player_save'] = player?.toJson();

    // 支出エントリ
    final expenses = await loadExpenseEntries(userId: userId);
    results['expense_entries'] = expenses.map((e) => e.toJson()).toList();

    // デイリークエスト
    final daily = await loadDailyQuests(userId: userId);
    results['daily_quests'] = daily?.toJson();

    // 週間クエスト
    final weekly = await loadWeeklyQuests(userId: userId);
    results['weekly_quests'] = weekly.map((e) => e.toJson()).toList();

    // 試練クエスト
    final trial = await loadTrialQuest(userId: userId);
    results['trial_quest'] = trial?.toJson();

    return results;
  }

  // ─── ヘルパー ──────────────────────────────────────────────────

  /// Supabase から返された行データを ExpenseEntry.fromJson 用に変換
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

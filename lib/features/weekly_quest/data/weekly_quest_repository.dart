import 'package:kozuchi/features/weekly_quest/domain/models/active_weekly_quest.dart';
import 'package:kozuchi/features/weekly_quest/domain/models/weekly_quest.dart';

/// 週間クエストのデータ取得・選択を抽象化するリポジトリインターフェース
///
/// 実装はサーバーAPI（Supabase / Flaskサーバー）と差し替え可能。
/// テスト時は [MockWeeklyQuestRepository] を使用する。
abstract class WeeklyQuestRepository {
  /// 指定ユーザーの今週の選択待ちクエスト候補（3〜5件）を取得する
  Future<List<ActiveWeeklyQuest>> getPendingQuests(String userId);

  /// クエストを選択し、active状態に遷移させる
  Future<void> selectQuest(String userId, String questId);

  /// 指定ユーザーの現在アクティブな週間クエストを取得する
  /// 存在しない場合はnullを返す
  Future<ActiveWeeklyQuest?> getActiveQuest(String userId);
}

/// モック用の週間クエストリポジトリ
///
/// テストやAPI未接続時のプレースホルダーとして使用する。
/// 3〜5件の固定クエスト候補を返す。
class MockWeeklyQuestRepository implements WeeklyQuestRepository {
  /// 選択されたクエストID（テスト検証用）
  String? selectedQuestId;

  /// 返すクエスト候補数（3〜5、デフォルト4）
  final int candidateCount;

  MockWeeklyQuestRepository({this.candidateCount = 4});

  @override
  Future<List<ActiveWeeklyQuest>> getPendingQuests(String userId) async {
    final allQuests = _buildMockQuests();
    return allQuests.take(candidateCount.clamp(3, 5)).map((q) {
      return ActiveWeeklyQuest(
        quest: q,
        status: WeeklyQuestStatus.pending,
      );
    }).toList();
  }

  @override
  Future<void> selectQuest(String userId, String questId) async {
    selectedQuestId = questId;
  }

  @override
  Future<ActiveWeeklyQuest?> getActiveQuest(String userId) async {
    if (selectedQuestId == null) return null;
    final quest = _buildMockQuests().firstWhere(
      (q) => q.id == selectedQuestId,
      orElse: () => _buildMockQuests().first,
    );
    return ActiveWeeklyQuest(
      quest: quest,
      status: WeeklyQuestStatus.active,
      selectedAt: DateTime.now(),
    );
  }

  List<WeeklyQuest> _buildMockQuests() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return [
      WeeklyQuest(
        id: 'quest_mock_01',
        title: '今週は食費を¥10,000以内に',
        description: '自炊を心がけ、外食を控えめに。'
            '手作りの食事は心も満たす。',
        targetCategory: '食費',
        budgetLimit: 10000,
        currentAvgSpend: 12000,
        difficulty: QuestDifficulty.easy,
        generatedAt: now,
        weekStart: monday,
        templateId: 'budgetLimit',
      ),
      WeeklyQuest(
        id: 'quest_mock_02',
        title: '今週は娯楽費を¥5,000以内に',
        description: '図書館や公園など、お金をかけない'
            '楽しみ方を見つけてみよう。',
        targetCategory: '娯楽',
        budgetLimit: 5000,
        currentAvgSpend: 8000,
        difficulty: QuestDifficulty.medium,
        generatedAt: now,
        weekStart: monday,
        templateId: 'budgetLimit',
      ),
      WeeklyQuest(
        id: 'quest_mock_03',
        title: '今週の総支出を¥30,000以内に',
        description: '全カテゴリで少しずつ意識しよう。'
            'レシートを見返す習慣をつけるのが近道。',
        targetCategory: '総支出',
        budgetLimit: 30000,
        currentAvgSpend: 40000,
        difficulty: QuestDifficulty.hard,
        generatedAt: now,
        weekStart: monday,
        templateId: 'totalCap',
      ),
      WeeklyQuest(
        id: 'quest_mock_04',
        title: '今週は交際費を¥8,000以内に',
        description: '人付き合いも大切だが、無理のない範囲で。'
            'お茶や散歩で十分なことも多い。',
        targetCategory: '交際費',
        budgetLimit: 8000,
        currentAvgSpend: 10000,
        difficulty: QuestDifficulty.easy,
        generatedAt: now,
        weekStart: monday,
        templateId: 'budgetLimit',
      ),
      WeeklyQuest(
        id: 'quest_mock_05',
        title: '今週は交通費を¥3,000以内に',
        description: 'できる範囲で徒歩や自転車に切り替えて。'
            '健康にも良い一石二鳥の挑戦だ。',
        targetCategory: '交通費',
        budgetLimit: 3000,
        currentAvgSpend: 5000,
        difficulty: QuestDifficulty.medium,
        generatedAt: now,
        weekStart: monday,
        templateId: 'frequencyReduce',
      ),
    ];
  }
}

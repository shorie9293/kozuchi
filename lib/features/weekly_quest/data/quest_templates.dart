/// 週間クエスト テンプレート定義
///
/// クエストのバリエーションを確保するためのテンプレートシステム。
/// 各テンプレートは異なるタイプの支出制限チャレンジを生成する。
///
/// ## テンプレートタイプ
///
/// 1. **budget_limit**: 単一カテゴリの予算上限
///    「今週は{category}を¥{limit}以内に」
///
/// 2. **frequency_reduce**: 支出回数制限
///    「今週は{category}の支出を{count}回までに」
///
/// 3. **compare_previous**: 先週比削減
///    「先週より{category}を{percent}%削減しよう」
///
/// 4. **total_cap**: 総支出上限
///    「今週の総支出を¥{total}以内に」
///
/// 5. **no_spend_day**: 無支出デーチャレンジ
///    「今週は{category}に使わない日を{days}日作ろう」

/// クエストテンプレートタイプ
enum QuestTemplateType {
  budgetLimit,
  frequencyReduce,
  comparePrevious,
  totalCap,
  noSpendDay,
}

/// クエストテンプレート定義
class QuestTemplate {
  /// テンプレートの種類
  final QuestTemplateType type;

  /// テンプレートID（ユニーク）
  String get id => type.name;

  /// タイトル生成関数
  /// [category] カテゴリ名、[limit] 制限値、[param2] 追加パラメータ
  final String Function(String category, int limit, int param2) titleBuilder;

  /// 説明文生成関数（守護神の口調）
  final String Function(
      String category, int limit, int avg, int param2) descriptionBuilder;

  /// 予算上限の計算方法（avgからの削減率 %）
  /// easy: 5-10%, medium: 15-20%, hard: 25-30%
  /// difficulty由来のばらつきを含む
  final int Function(String category, int avgSpend, double reductionRate)
      budgetCalculator;

  const QuestTemplate({
    required this.type,
    required this.titleBuilder,
    required this.descriptionBuilder,
    required this.budgetCalculator,
  });

  /// 全テンプレート一覧
  static List<QuestTemplate> get all => [
        _budgetLimitTemplate,
        _frequencyReduceTemplate,
        _comparePreviousTemplate,
        _totalCapTemplate,
        _noSpendDayTemplate,
      ];

  /// テンプレートID→テンプレートのマップ
  static Map<String, QuestTemplate> get byId =>
      {for (final t in all) t.id: t};
}

// ============================================================
//  テンプレート1: 単一カテゴリ予算上限
// ============================================================

final _budgetLimitTemplate = QuestTemplate(
  type: QuestTemplateType.budgetLimit,
  titleBuilder: (category, limit, _) => '今週は$categoryを¥$limit以内に',
  descriptionBuilder: (category, limit, avg, _) {
    final reduction = avg - limit;
    if (reduction > 0) {
      return '先週の$categoryは¥$avgだった。'
          '今週はそれを¥$reduction減らし、¥$limit以内に収めてみよう。'
          '小さな節約が大きな悟りを生む。';
    }
    return '今週の$categoryは¥$limitを目安に。'
        '無理のない範囲で挑戦してみよう。';
  },
  budgetCalculator: (category, avgSpend, reductionRate) {
    final reduction = (avgSpend * reductionRate / 100).round();
    // 最低¥300は残す
    return (avgSpend - reduction).clamp(300, avgSpend);
  },
);

// ============================================================
//  テンプレート2: 支出回数制限
// ============================================================

final _frequencyReduceTemplate = QuestTemplate(
  type: QuestTemplateType.frequencyReduce,
  titleBuilder: (category, _, maxCount) =>
      '今週は$categoryの支出を${maxCount}回までに',
  descriptionBuilder: (category, limit, avg, maxCount) {
    return '今週は$categoryに使う回数を${maxCount}回までに制限しよう。'
        '1回あたり¥${(limit ~/ maxCount.clamp(1, 99))}が目安。'
        '回数を意識するだけで無駄遣いが減るものだ。';
  },
  budgetCalculator: (category, avgSpend, reductionRate) {
    // 支出回数制限でも総額ベースで計算
    // 回数は別途QuestTemplateContextで決定
    final reduction = (avgSpend * reductionRate / 100).round();
    return (avgSpend - reduction).clamp(300, avgSpend);
  },
);

// ============================================================
//  テンプレート3: 先週比削減
// ============================================================

final _comparePreviousTemplate = QuestTemplate(
  type: QuestTemplateType.comparePrevious,
  titleBuilder: (category, _, percent) =>
      '先週より$categoryを$percent%削減しよう',
  descriptionBuilder: (category, limit, avg, percent) {
    return '先週の$category（¥$avg）から${percent}%の削減に挑戦。'
        '今週の目標は¥$limit。'
        '前週比で見ると達成感がひとしおだ。';
  },
  budgetCalculator: (category, avgSpend, reductionRate) {
    final reduction = (avgSpend * reductionRate / 100).round();
    return (avgSpend - reduction).clamp(500, avgSpend);
  },
);

// ============================================================
//  テンプレート4: 総支出上限
// ============================================================

final _totalCapTemplate = QuestTemplate(
  type: QuestTemplateType.totalCap,
  titleBuilder: (_, limit, __) => '今週の総支出を¥$limit以内に',
  descriptionBuilder: (category, limit, avg, _) {
    final reduction = avg - limit;
    if (reduction > 0) {
      return '先週の総支出は¥$avgだった。'
          '今週は¥$reduction減らして¥$limitに挑戦。'
          '全カテゴリで少しずつ意識すれば達成できるはずだ。';
    }
    return '今週の総支出を¥$limit以内に。'
        '全体を見渡すことが悟りへの第一歩。';
  },
  budgetCalculator: (category, avgSpend, reductionRate) {
    final reduction = (avgSpend * reductionRate / 100).round();
    return (avgSpend - reduction).clamp(2000, avgSpend);
  },
);

// ============================================================
//  テンプレート5: 無支出デー
// ============================================================

final _noSpendDayTemplate = QuestTemplate(
  type: QuestTemplateType.noSpendDay,
  titleBuilder: (category, _, days) => '今週は$categoryに使わない日を${days}日作ろう',
  descriptionBuilder: (category, limit, avg, days) {
    return '今週${days}日間、$categoryを一切使わない日を作ろう。'
        '冷蔵庫の残り物や手持ちのものでやりくりする工夫が悟りを深める。'
        '目安支出は¥$limit。';
  },
  budgetCalculator: (category, avgSpend, reductionRate) {
    final reduction = (avgSpend * reductionRate / 100).round();
    return (avgSpend - reduction).clamp(300, avgSpend);
  },
);

// ============================================================
//  テンプレート選択ヘルパー
// ============================================================

/// カテゴリ別に推奨テンプレートを返す
///
/// - '総支出' には totalCap のみ
/// - 支出が少ないカテゴリには budgetLimit が無難
/// - 支出が多いカテゴリには frequencyReduce や noSpendDay も効果的
List<QuestTemplateType> recommendedTemplateTypes(
    String category, int avgSpend) {
  if (category == '総支出') {
    return [QuestTemplateType.totalCap];
  }
  if (avgSpend <= 1000) {
    return [QuestTemplateType.budgetLimit, QuestTemplateType.noSpendDay];
  }
  return QuestTemplateType.values.toList();
}

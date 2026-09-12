import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';

/// タグ定義とタグ紐付けの永続化リポジトリ
///
/// SharedPreferences に JSON 文字列として保存する。
/// - タグ定義: `kozuchi_tags_definitions`
/// - 取引キー → タグID列: `kozuchi_tags_assignments`
///
/// 破損データは空として扱い、例外を投げない。
class TagRepository {
  static const String tagsKey = 'kozuchi_tags_definitions';
  static const String assignmentsKey = 'kozuchi_tags_assignments';

  const TagRepository();

  // ── タグ定義 ─────────────────────────────────────

  /// タグ定義を読み出す（未保存・破損時は空リスト）。
  Future<List<ExpenseTag>> loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(tagsKey);
    if (jsonString == null) return const [];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return const [];
      final tags = <ExpenseTag>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final tag = ExpenseTag.fromJson(item);
          if (tag.id.isNotEmpty) tags.add(tag);
        } else if (item is Map) {
          final tag = ExpenseTag.fromJson(Map<String, dynamic>.from(item));
          if (tag.id.isNotEmpty) tags.add(tag);
        }
      }
      return List.unmodifiable(tags);
    } catch (_) {
      return const [];
    }
  }

  /// タグ定義を保存する。
  Future<void> saveTags(List<ExpenseTag> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      tagsKey,
      jsonEncode(tags.map((t) => t.toJson()).toList()),
    );
  }

  /// タグを新規作成し、更新後のタグ一覧を返す。
  ///
  /// [id] 未指定時は現在時刻から生成する（試練では明示指定できる）。
  /// 名前が空白のみの場合は [ArgumentError]。
  Future<List<ExpenseTag>> createTag(
    String name, {
    String? id,
    int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'タグ名を空にはできません');
    }
    final tags = await loadTags();
    final newTag = ExpenseTag(
      id: id ?? 'tag_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      colorValue: colorValue ?? ExpenseTag.defaultColorValue,
    );
    final updated = [...tags.where((t) => t.id != newTag.id), newTag];
    await saveTags(updated);
    return updated;
  }

  /// タグ名を変更し、更新後のタグ一覧を返す。
  ///
  /// 存在しないIDを指定した場合は変更せずそのまま返す。
  Future<List<ExpenseTag>> renameTag(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'タグ名を空にはできません');
    }
    final tags = await loadTags();
    final updated = [
      for (final tag in tags)
        tag.id == id ? tag.copyWith(name: trimmed) : tag,
    ];
    await saveTags(updated);
    return updated;
  }

  /// タグを削除し、更新後のタグ一覧を返す。
  ///
  /// 紐付けからも該当タグIDを取り除く（空になった紐付けは削除する）。
  Future<List<ExpenseTag>> deleteTag(String id) async {
    final tags = await loadTags();
    final updated = tags.where((t) => t.id != id).toList();
    await saveTags(updated);

    final assignments = await loadAssignments();
    var changed = false;
    final next = <String, List<String>>{};
    assignments.forEach((key, tagIds) {
      if (!tagIds.contains(id)) {
        next[key] = tagIds;
        return;
      }
      changed = true;
      final remaining = tagIds.where((t) => t != id).toList();
      if (remaining.isNotEmpty) next[key] = remaining;
    });
    if (changed) await saveAssignments(next);
    return List.unmodifiable(updated);
  }

  // ── 紐付け ───────────────────────────────────────

  /// 紐付けマップを読み出す（未保存・破損時は空マップ）。
  Future<Map<String, List<String>>> loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(assignmentsKey);
    if (jsonString == null) return const {};

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return const {};
      final result = <String, List<String>>{};
      decoded.forEach((key, value) {
        if (key is! String || key.isEmpty) return;
        if (value is! List) return;
        final tags = <String>[
          for (final v in value)
            if (v is String && v.isNotEmpty) v,
        ];
        if (tags.isNotEmpty) result[key] = List.unmodifiable(tags);
      });
      return Map.unmodifiable(result);
    } catch (_) {
      return const {};
    }
  }

  /// 紐付けマップを保存する。
  Future<void> saveAssignments(Map<String, List<String>> assignments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(assignmentsKey, jsonEncode(assignments));
  }

  /// 指定取引キーのタグID列を取得する（無ければ空リスト）。
  Future<List<String>> tagsFor(String transactionKey) async {
    final assignments = await loadAssignments();
    return assignments[transactionKey] ?? const [];
  }

  /// 指定取引のタグを差し替える（空リストでタグ解除）。
  Future<Map<String, List<String>>> assignTags(
    String transactionKey,
    List<String> tagIds,
  ) async {
    final assignments = Map<String, List<String>>.from(
      await loadAssignments(),
    );
    final distinct = <String>[];
    final seen = <String>{};
    for (final tagId in tagIds) {
      if (tagId.isEmpty) continue;
      if (seen.add(tagId)) distinct.add(tagId);
    }

    if (distinct.isEmpty) {
      assignments.remove(transactionKey);
    } else {
      assignments[transactionKey] = List.unmodifiable(distinct);
    }
    await saveAssignments(assignments);
    return assignments;
  }
}

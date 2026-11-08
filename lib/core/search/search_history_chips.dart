import 'package:flutter/material.dart';

import 'package:kozuchi/core/search/search_history.dart';

/// 検索履歴チップ群。
///
/// [SearchHistory.entries] を新しい順に [ActionChip] で横並び表示する。
/// 空なら何も描画しない（高さ 0 の [SizedBox.shrink]）。
class SearchHistoryChips extends StatelessWidget {
  /// 表示する検索語（新しい順）。
  final List<String> entries;

  /// チップ選択時に選択語を受け取るコールバック。
  final ValueChanged<String> onSelected;

  const SearchHistoryChips({
    super.key,
    required this.entries,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: '検索履歴',
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final term in entries)
            ActionChip(
              key: ValueKey<String>('search-history-chip-$term'),
              avatar: const Icon(Icons.history, size: 16),
              label: Text(term),
              visualDensity: VisualDensity.compact,
              onPressed: () => onSelected(term),
            ),
        ],
      ),
    );
  }
}
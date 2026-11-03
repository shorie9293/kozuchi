import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

import 'package:kozuchi/features/help/domain/help_catalog.dart';
import 'package:kozuchi/features/help/domain/help_topic.dart';
import 'package:kozuchi/features/help/presentation/help_app_keys.dart';

/// 「遊び方・ヘルプ」画面。
///
/// 初回チュートリアルを読み返すための画面。文言はチュートリアルから
/// [HelpCatalog] 経由で流用するため、ここでは文章を持たない。
/// 必須依存はなく、[catalog] は試練用に差し替え可能。
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.catalog});

  /// 目次。省略時はチュートリアル由来の既定目次。
  final HelpCatalog? catalog;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late final HelpCatalog _catalog = widget.catalog ?? HelpCatalog();
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _searchField() {
    return SemanticHelper.textField(
      testId: SemanticHelper.createTestId(
        SemanticTypes.textField,
        'help_search',
      ),
      label: 'ヘルプを検索',
      child: TextField(
        key: HelpAppKeys.searchField,
        controller: _controller,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _query = value),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'キーワードで検索',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _topicTile(HelpTopic topic) {
    return SemanticHelper.interactive(
      testId: SemanticHelper.createTestId(
        SemanticTypes.listItem,
        'help_topic_${topic.id}',
      ),
      label: topic.title,
      child: ExpansionTile(
        key: HelpAppKeys.topicTile(topic.id),
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(topic.title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.body,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = _catalog.search(_query);
    return Scaffold(
      key: HelpAppKeys.screen,
      appBar: AppBar(title: const Text('遊び方・ヘルプ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _searchField(),
          ),
          Expanded(
            child: topics.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '該当する項目がありません',
                        key: HelpAppKeys.emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    key: HelpAppKeys.list,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _topicTile(topics[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

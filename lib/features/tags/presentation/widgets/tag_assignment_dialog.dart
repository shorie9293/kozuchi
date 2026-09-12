import 'package:flutter/material.dart';

import 'package:kozuchi/features/tags/domain/models/expense_tag.dart';
import 'package:kozuchi/features/tags/presentation/tag_app_keys.dart';

/// 取引にタグを割り当てるダイアログを表示する。
///
/// 確定時は選択されたタグID列、キャンセル時は null を返す。
Future<List<String>?> showTagAssignmentDialog(
  BuildContext context, {
  required List<ExpenseTag> tags,
  List<String> selectedTagIds = const [],
}) {
  final selected = <String>{...selectedTagIds};

  return showDialog<List<String>>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            key: TagAppKeys.assignmentDialog,
            title: const Text('タグを付ける'),
            content: SizedBox(
              width: double.maxFinite,
              child: tags.isEmpty
                  ? const Text('タグがありません')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final tag in tags)
                          CheckboxListTile(
                            value: selected.contains(tag.id),
                            title: Text(tag.name),
                            secondary: CircleAvatar(
                              radius: 8,
                              backgroundColor: Color(tag.colorValue),
                            ),
                            onChanged: (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  selected.add(tag.id);
                                } else {
                                  selected.remove(tag.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                key: TagAppKeys.assignmentSaveButton,
                onPressed: () =>
                    Navigator.of(dialogContext).pop(selected.toList()),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
}

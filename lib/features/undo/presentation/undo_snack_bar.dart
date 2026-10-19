import 'package:flutter/material.dart';

/// Undo スナックバーの「元に戻す」アクションのキー（試練用）。
const undoActionKey = Key('undo_snackbar_action');

/// 取り消し可能な操作の後に表示する Undo スナックバー。
///
/// [message] を本文に、[onUndo] を「元に戻す」アクションとして表示する。
/// [duration] 経過で自動的に消える（既定5秒）。
///
/// 呼び出し側は操作を**即時実行**した上で本関数を呼び、
/// [onUndo] で復元処理を行う（楽観的UI＋Undo 方式）。
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: SnackBarAction(
        key: undoActionKey,
        label: '元に戻す',
        onPressed: onUndo,
      ),
    ),
  );
}

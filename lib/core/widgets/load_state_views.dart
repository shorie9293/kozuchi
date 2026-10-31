import 'package:flutter/material.dart';

/// 読込失敗ビュー。
///
/// 「0件」と取り違えないよう、空状態（[LoadEmptyView]）とは
/// 別ウィジェット・別Key・別文言で構成する。
/// [onRetry] が null のときは再試行ボタンを出さない（再試行不能な失敗）。
class LoadErrorView extends StatelessWidget {
  /// 失敗メッセージ（利用者向け日本語）
  final String message;

  /// 再試行ハンドラ（null なら再試行ボタン非表示）
  final VoidCallback? onRetry;

  const LoadErrorView({
    super.key = const ValueKey('load_error_view'),
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const ValueKey('load_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 0件ビュー。
///
/// 取得に成功したが0件だった場合のみ用いる。
/// 読込失敗をここへ流してはならない（[LoadErrorView] を使う）。
class LoadEmptyView extends StatelessWidget {
  /// 空状態の説明文（利用者向け日本語）
  final String message;

  const LoadEmptyView({
    super.key = const ValueKey('load_empty_view'),
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

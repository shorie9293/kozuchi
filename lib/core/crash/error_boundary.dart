import 'package:flutter/material.dart';

/// 描画中の例外を握り、アプリ全体を白画面にしないための受け皿。
///
/// [ErrorWidget.builder] を差し替えることで、build 中に投げられた例外が
/// 起きた瞬間にこの境界の所有ツリーを復帰UIへ切り替える。
/// 復帰UIの「再読み込み」は generation を進めて [child] を作り直す。
///
/// 既存の MaterialApp 構成は変更しない（ルートを包むだけで使える）。
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
  });

  /// 正常時に表示するツリー。
  final Widget child;

  /// 例外を検知したときに呼ばれる（ログ記録などの副作用用）。
  final void Function(Object error, StackTrace? stack)? onError;

  /// 復帰UIの「再読み込み」ボタン。
  static const Key retryButtonKey = Key('error_boundary_retry');

  /// 復帰UIの本文。
  static const Key messageKey = Key('error_boundary_message');

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  ErrorWidgetBuilder? _previousBuilder;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = _buildErrorWidget;
  }

  @override
  void dispose() {
    // 差し替えは必ず元へ戻す（他の画面や試練へ影響を漏らさない）。
    ErrorWidget.builder = _previousBuilder ?? ErrorWidget.builder;
    super.dispose();
  }

  Widget _buildErrorWidget(FlutterErrorDetails details) {
    _report(details.exception, details.stack);
    // 例外が出た部分だけを空にし、復帰UIは境界側で出す。
    return const SizedBox.shrink();
  }

  void _report(Object error, StackTrace? stack) {
    if (!mounted || _error != null) return;
    _error = error;
    widget.onError?.call(error, stack);
    // build 中に setState できないため、フレーム終了後に切り替える。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _error == null) return;
      setState(() {});
    });
  }

  void _retry() {
    setState(() {
      _error = null;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _buildRecoveryScreen();
    return KeyedSubtree(
      key: ValueKey<int>(_generation),
      child: widget.child,
    );
  }

  /// MaterialApp の外側（ルート）でも描けるよう、テーマ非依存で組む。
  Widget _buildRecoveryScreen() {
    const bg = Color(0xFFFDFBF7);
    const fg = Color(0xFF3A2E28);
    const accent = Color(0xFF8C2F39);
    return Material(
      color: bg,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: accent,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '表示中に問題が発生しました',
                    key: ErrorBoundary.messageKey,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ご迷惑をおかけしています。再読み込みで復帰できます。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: fg),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    label: '再読み込み',
                    child: ElevatedButton(
                      key: ErrorBoundary.retryButtonKey,
                      onPressed: _retry,
                      child: const Text('再読み込み'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

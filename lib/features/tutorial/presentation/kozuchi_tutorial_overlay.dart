import 'package:flutter/material.dart';
import 'package:kozuchi/features/tutorial/domain/kozuchi_tutorial_step.dart';
import 'package:kozuchi/features/tutorial/data/kozuchi_tutorial_service.dart';

/// コヅチ チュートリアル吹き出しオーバーレイ
///
/// 半透明の背景＋吹き出しでガイドテキストを表示。
/// 「次へ」「スキップ」ボタン付き。
class KozuchiTutorialOverlay extends StatefulWidget {
  final KozuchiTutorialStep step;
  final Widget child;
  final VoidCallback? onComplete;

  const KozuchiTutorialOverlay({
    super.key,
    required this.step,
    required this.child,
    this.onComplete,
  });

  @override
  State<KozuchiTutorialOverlay> createState() => _KozuchiTutorialOverlayState();
}

class _KozuchiTutorialOverlayState extends State<KozuchiTutorialOverlay> {
  void _next() {
    final next = widget.step.next;
    if (next != null) {
      setState(() {
        // 親で管理する想定（ここではonCompleteで代替）
      });
      widget.onComplete?.call();
    }
  }

  void _skip() {
    KozuchiTutorialService.markCompleted();
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景の子Widget
        widget.child,
        // 半透明オーバーレイ
        GestureDetector(
          onTap: () {}, // タップを吸収
          child: Container(color: Colors.black54),
        ),
        // 吹き出し
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 吹き出し矢印
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Icon(Icons.arrow_drop_up, color: colorScheme.primary, size: 32),
                  ),
                  // タイトル
                  Text(
                    widget.step.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // 説明文
                  Text(
                    widget.step.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // ボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _skip,
                        child: Text(
                          'スキップ',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _next,
                        child: Text(
                          widget.step.next != null ? '次へ' : '始める',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 空状態の内容（純粋データ）。
///
/// 文言は呼び出し側が持ち、この部品は「見出し・説明・次の一手」の
/// 組み合わせだけを表す。描画は [EmptyStateView] が担う。
///
/// 不正な組み合わせは生成時点で弾く（[ArgumentError]）：
/// - [title] が空文字・空白のみ
/// - [actionLabel] と [onAction] の片方だけが指定されている
///
/// 試練で確実に検出できるよう `assert` ではなくコンストラクタ本体で投げる
/// （release ビルドでも同じ不変条件を守る）。
class EmptyStateSpec {
  /// 見出し（必須）。
  final String title;

  /// 補足説明（任意）。null なら描画しない。
  final String? description;

  /// 行動ボタンの文言（任意）。[onAction] と対で指定する。
  final String? actionLabel;

  /// 行動ボタンの処理（任意）。[actionLabel] と対で指定する。
  final void Function()? onAction;

  EmptyStateSpec({
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', '空状態の見出しは空にできない');
    }
    if ((actionLabel == null) != (onAction == null)) {
      throw ArgumentError(
        'actionLabel と onAction は両方指定するか、両方省略せよ',
      );
    }
  }

  /// 行動ボタンを描くか。
  bool get hasAction => actionLabel != null && onAction != null;

  /// 補足説明を描くか。
  bool get hasDescription => description != null;
}

/// 空状態ビュー。
///
/// アイコン（任意）・見出し・説明（任意）・行動ボタン（任意）を
/// 中央に縦積みする。「まだ何もない」で終わらせず、次の一手を差し出す。
/// ボタンは [EmptyStateSpec.actionLabel] / [EmptyStateSpec.onAction] が
/// 両方揃っているときだけ描く。
///
/// テストで一意に掴めるよう [key] は必須。
class EmptyStateView extends StatelessWidget {
  /// 表示内容。
  final EmptyStateSpec spec;

  /// 見出し上のアイコン（任意）。null なら描画しない。
  final IconData? icon;

  const EmptyStateView({
    required super.key,
    required this.spec,
    this.icon,
  });

  /// 行動ボタンの Key（画面ごとに一意になるよう親が包む）。
  static const Key actionButtonKey = ValueKey('empty_state_action_button');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 64,
                color: colorScheme.outline.withAlpha(128),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              spec.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colorScheme.outline),
            ),
            if (spec.hasDescription) ...[
              const SizedBox(height: 8),
              Text(
                spec.description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.outline.withAlpha(204),
                ),
              ),
            ],
            if (spec.hasAction) ...[
              const SizedBox(height: 16),
              SemanticHelper.interactive(
                testId: 'empty_state_btn_action',
                label: spec.actionLabel!,
                child: FilledButton(
                  key: actionButtonKey,
                  onPressed: spec.onAction,
                  child: Text(spec.actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

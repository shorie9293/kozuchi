import 'package:flutter/services.dart';

/// 操作の触覚フィードバック（軽いクリック）。
///
/// **await してはならない。** flutter_test ではプラットフォームチャネルが
/// 未解決のため、`await` すると Future が永久に完了せず試練が固まる（禍津）。
/// ここでは意図的に fire-and-forget とし、[Future.ignore] で未処理例外も握る。
void hapticTap() => HapticFeedback.selectionClick().ignore();

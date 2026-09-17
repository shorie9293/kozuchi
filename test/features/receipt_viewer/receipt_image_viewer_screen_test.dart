import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kozuchi/features/receipt_viewer/data/receipt_image_loader.dart';
import 'package:kozuchi/features/receipt_viewer/presentation/receipt_viewer_app_keys.dart';
import 'package:kozuchi/features/receipt_viewer/presentation/screens/receipt_image_viewer_screen.dart';

/// 実画像デコードを起こさないためのダミー imageBuilder。
Widget fakeImageBuilder(BuildContext context, Uint8List bytes) {
  // 画面側の KeyedSubtree が viewerImage を付与するため、ここでは key を付けない。
  return Container(
    width: 100,
    height: 100,
    color: Colors.red,
    child: Text('bytes:${bytes.length}'),
  );
}

/// load が完了しないローダ（ローディング状態の試練用）。
class _PendingReceiptImageLoader implements ReceiptImageLoader {
  @override
  Future<Uint8List?> load(String path) => Completer<Uint8List?>().future;
}

void main() {
  testWidgets('ローディング中は viewerLoading を表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptImageViewerScreen(
          path: '/tmp/receipt.jpg',
          loader: _PendingReceiptImageLoader(),
          imageBuilder: fakeImageBuilder,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(ReceiptViewerAppKeys.viewerLoading), findsOneWidget);
    expect(find.byKey(ReceiptViewerAppKeys.viewerEmpty), findsNothing);
  });

  testWidgets('成功時は viewerImage を表示する', (tester) async {
    final loader = InMemoryReceiptImageLoader({
      '/tmp/receipt.jpg': Uint8List.fromList([1, 2, 3]),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptImageViewerScreen(
          path: '/tmp/receipt.jpg',
          loader: loader,
          imageBuilder: fakeImageBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ReceiptViewerAppKeys.viewerScreen), findsOneWidget);
    expect(find.byKey(ReceiptViewerAppKeys.viewerImage), findsOneWidget);
    expect(find.byKey(ReceiptViewerAppKeys.viewerEmpty), findsNothing);
    expect(find.byKey(ReceiptViewerAppKeys.viewerTitle), findsOneWidget);
  });

  testWidgets('null バイトは viewerEmpty と再読込ボタンを表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptImageViewerScreen(
          path: '/tmp/missing.jpg',
          loader: const InMemoryReceiptImageLoader({}),
          imageBuilder: fakeImageBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ReceiptViewerAppKeys.viewerEmpty), findsOneWidget);
    expect(find.byKey(ReceiptViewerAppKeys.viewerErrorMessage), findsOneWidget);
    expect(find.byKey(ReceiptViewerAppKeys.viewerRetryButton), findsOneWidget);
    expect(
      find.text('レシート画像が見つかりません。端末から削除された可能性があります。'),
      findsOneWidget,
    );
  });

  testWidgets('不正パスは viewerEmpty で不正メッセージを表示する', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptImageViewerScreen(
          path: '   ',
          loader: const InMemoryReceiptImageLoader({}),
          imageBuilder: fakeImageBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ReceiptViewerAppKeys.viewerEmpty), findsOneWidget);
    expect(find.text('レシート画像のパスが不正です。'), findsOneWidget);
  });

  testWidgets('再読込ボタンで再ロードする', (tester) async {
    final loader = InMemoryReceiptImageLoader({});
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptImageViewerScreen(
          path: '/tmp/receipt.jpg',
          loader: loader,
          imageBuilder: fakeImageBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ReceiptViewerAppKeys.viewerEmpty), findsOneWidget);

    // 画像を後から登録して再読込。
    loader.store['/tmp/receipt.jpg'] = Uint8List.fromList([9]);
    await tester.tap(find.byKey(ReceiptViewerAppKeys.viewerRetryButton));
    await tester.pumpAndSettle();
    expect(find.byKey(ReceiptViewerAppKeys.viewerImage), findsOneWidget);
  });
}

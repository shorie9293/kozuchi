import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// レポートカードの PNG 書き出し抽象
abstract class ReportCardCapture {
  Future<Uint8List?> capture(GlobalKey boundaryKey);
}

/// RepaintBoundary 実装のキャプチャ
class RepaintBoundaryCapture implements ReportCardCapture {
  const RepaintBoundaryCapture();

  @override
  Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.attached) {
      return null;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

/// PNG の共有・保存抽象
abstract class ReportCardExporter {
  Future<void> export({
    required Uint8List png,
    required String fileName,
    String? text,
  });
}

/// share_plus 実装のエクスポーター
class SharePlusReportCardExporter implements ReportCardExporter {
  const SharePlusReportCardExporter();

  @override
  Future<void> export({
    required Uint8List png,
    required String fileName,
    String? text,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(png, name: fileName, mimeType: 'image/png'),
        ],
        text: text,
      ),
    );
  }
}

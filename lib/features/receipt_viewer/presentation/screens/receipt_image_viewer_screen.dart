import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:kozuchi/features/receipt_viewer/data/receipt_image_loader.dart';
import 'package:kozuchi/features/receipt_viewer/domain/models/receipt_image_ref.dart';
import 'package:kozuchi/features/receipt_viewer/presentation/receipt_viewer_app_keys.dart';

/// レシート原本画像を閲覧する画面。
///
/// [path] の画像を [loader] で非同期ロードし、
/// InteractiveViewer で拡大縮小可能にして表示する。
///
/// 状態: ローディング中 / 成功 / 空（ファイル不在・null バイト） /
/// 不正パス（[ReceiptImageRef.tryFromPath] が null）。
///
/// テスト時は [loader] と [imageBuilder] を差し替えることで
/// 実画像デコード（ヘッドレスで完走しない禍津）を回避できる。
class ReceiptImageViewerScreen extends StatefulWidget {
  /// レシート画像のパス（null/空は不正パス扱い）。
  final String? path;

  /// 画像ローダ。null なら [FileReceiptImageLoader] を使う。
  final ReceiptImageLoader? loader;

  /// AppBar タイトル。
  final String title;

  /// 画像構築関数（テストで実デコードを避けるため差し替え可能）。
  /// null なら [Image.memory]（contain・gaplessPlayback）で構築する。
  final Widget Function(BuildContext context, Uint8List bytes)? imageBuilder;

  const ReceiptImageViewerScreen({
    super.key,
    required this.path,
    this.loader,
    this.title = 'レシート原本',
    this.imageBuilder,
  });

  @override
  State<ReceiptImageViewerScreen> createState() =>
      _ReceiptImageViewerScreenState();
}

class _ReceiptImageViewerScreenState extends State<ReceiptImageViewerScreen> {
  bool _loading = true;
  Uint8List? _bytes;
  bool _invalidPath = false;

  late final ReceiptImageLoader _loader;

  @override
  void initState() {
    super.initState();
    _loader = widget.loader ?? const FileReceiptImageLoader();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReceiptImageViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _load();
    }
  }

  /// 画像を（再）読み込みする。
  Future<void> _load() async {
    final ref = ReceiptImageRef.tryFromPath(widget.path);
    if (ref == null) {
      setState(() {
        _loading = false;
        _invalidPath = true;
        _bytes = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _invalidPath = false;
    });
    final bytes = await _loader.load(ref.path);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _bytes = bytes;
    });
  }

  /// 既定の画像構築（実デコードが走る。テストでは imageBuilder で差し替え）。
  Widget _defaultImageBuilder(BuildContext context, Uint8List bytes) {
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ReceiptViewerAppKeys.viewerScreen,
      appBar: AppBar(
        title: Text(
          widget.title,
          key: ReceiptViewerAppKeys.viewerTitle,
        ),
        actions: [
          IconButton(
            key: ReceiptViewerAppKeys.viewerRetryButton,
            tooltip: '再読込',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: ReceiptViewerAppKeys.viewerLoading,
        ),
      );
    }
    if (_invalidPath) {
      return _buildEmpty(
        context,
        'レシート画像のパスが不正です。',
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return _buildEmpty(
        context,
        'レシート画像が見つかりません。端末から削除された可能性があります。',
      );
    }
    // 成功: InteractiveViewer で拡大縮小可能にして表示。
    return InteractiveViewer(
      maxScale: 4,
      child: Center(
        child: KeyedSubtree(
          key: ReceiptViewerAppKeys.viewerImage,
          child: (widget.imageBuilder ?? _defaultImageBuilder)(
            context,
            bytes,
          ),
        ),
      ),
    );
  }

  /// 空状態（ファイル不在／不正パス）の表示。
  Widget _buildEmpty(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        key: ReceiptViewerAppKeys.viewerEmpty,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            key: ReceiptViewerAppKeys.viewerErrorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('再読込'),
          ),
        ],
      ),
    );
  }
}

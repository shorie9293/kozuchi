import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kozuchi/features/receipt_scanner/data/receipt_ocr_service.dart';

/// レシート撮影画面
///
/// カメラでレシートを撮影し、OCRで金額・店名を自動抽出する。
/// 抽出結果を確認後、呼び出し元に返す。
class ReceiptScannerScreen extends StatefulWidget {
  final ReceiptOcrService ocrService;

  /// テスト用にImagePickerを差し替え可能にする
  final ImagePicker? picker;

  const ReceiptScannerScreen({
    super.key,
    required this.ocrService,
    this.picker,
  });

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  String? _imagePath;
  ReceiptOcrResult? _ocrResult;
  bool _isProcessing = false;
  bool _hasCaptured = false;

  ImagePicker get _picker => widget.picker ?? ImagePicker();

  /// image_pickerでカメラを起動しレシートを撮影する
  Future<void> _captureReceipt() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (photo == null) return; // ユーザーがキャンセル

      setState(() {
        _hasCaptured = true;
        _isProcessing = true;
        _imagePath = photo.path;
        _ocrResult = null; // 再撮影時は前回結果をクリア
      });

      // OCRを実行
      final result = await widget.ocrService.processImage(_imagePath!);

      if (!mounted) return;

      setState(() {
        _ocrResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('カメラの起動に失敗しました: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _confirmAndReturn() {
    if (_ocrResult == null) return;
    Navigator.of(context).pop(_ocrResult);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('レシート撮影'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // プレビュー領域
            _buildPreviewArea(colorScheme),
            const SizedBox(height: 24),

            // 撮影ボタン or 処理中表示
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _captureReceipt,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt),
                    const SizedBox(width: 8),
                    Text(_hasCaptured ? '再撮影' : 'レシートを撮影'),
                  ],
                ),
              ),
            if (_isProcessing) ...[
              const SizedBox(height: 8),
              Text(
                'レシートを解析中…',
                style: TextStyle(color: colorScheme.outline),
              ),
            ],

            // OCR結果表示
            if (_ocrResult != null) ...[
              const SizedBox(height: 24),
              _buildOcrResultCard(colorScheme),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _imagePath = null;
                        _ocrResult = null;
                      });
                    },
                    child: const Text('撮り直す'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _confirmAndReturn,
                    child: const Text('この内容で記録'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _ocrResult != null
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Center(
        child: _imagePath == null
            ? Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: colorScheme.outline,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '撮影完了',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildOcrResultCard(ColorScheme colorScheme) {
    final result = _ocrResult!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '📋 読み取り結果',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          _buildResultRow('店名', result.storeName ?? '（未検出）', colorScheme),
          const SizedBox(height: 8),
          _buildResultRow(
            '金額',
            result.amount != null ? '¥${result.amount}' : '（未検出）',
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, ColorScheme colorScheme) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.outline,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

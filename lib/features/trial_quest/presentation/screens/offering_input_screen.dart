import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/features/receipt_scanner/data/receipt_ocr_service.dart';
import 'package:kozuchi/features/receipt_scanner/presentation/screens/receipt_scanner_screen.dart';

/// 支出入力結果
class OfferingResult {
  final int amount;
  final String purpose;
  final String note;
  final String? receiptImagePath;
  final PlayerModel updatedPlayer;

  OfferingResult({
    required this.amount,
    required this.purpose,
    required this.note,
    this.receiptImagePath,
    required this.updatedPlayer,
  });
}

/// 支出入力画面
///
/// 金額＋用途＋一言メモを入力する。
/// 拡張2: レシート撮影による自動入力に対応。
class OfferingInputScreen extends StatefulWidget {
  final TrialQuest quest;
  final PlayerModel player;

  const OfferingInputScreen({
    super.key,
    required this.quest,
    required this.player,
  });

  @override
  State<OfferingInputScreen> createState() => _OfferingInputScreenState();
}

class _OfferingInputScreenState extends State<OfferingInputScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _purposeController;
  late final TextEditingController _noteController;
  String? _receiptImagePath;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.quest.suggestedOffering.toString(),
    );
    _purposeController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// レシート撮影画面を開く
  Future<void> _openReceiptScanner() async {
    final result = await Navigator.of(context).push<ReceiptOcrResult>(
      MaterialPageRoute(
        builder: (_) => ReceiptScannerScreen(
          ocrService: MockReceiptOcrService(),
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _receiptImagePath = result.imagePath;

      // OCR結果でフィールドを自動入力
      if (result.amount != null) {
        _amountController.text = result.amount.toString();
      }
      if (result.storeName != null && result.storeName!.isNotEmpty) {
        _purposeController.text = result.storeName!;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountController.text);
    final updatedPlayer = widget.player.performOffering(amount);
    Navigator.of(context).pop(OfferingResult(
      amount: amount,
      purpose: _purposeController.text,
      note: _noteController.text,
      receiptImagePath: _receiptImagePath,
      updatedPlayer: updatedPlayer,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('支出の記録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 説明文
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(widget.quest.advisor.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '支出（キシャ）とは、執着を手放す布施の行なり。'
                        '使った金は消えるのではなく、誰かの元へ「縁」として巡る。',
                        style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // レシート撮影ボタン（拡張2）
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openReceiptScanner,
                  icon: const Icon(Icons.receipt_long),
                  label: Text(_receiptImagePath != null ? '📷 レシート撮影済み' : '📷 レシートを撮影'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: _receiptImagePath != null
                          ? colorScheme.primary
                          : colorScheme.outline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 金額入力
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '支出金額（円）',
                  prefixText: '¥ ',
                  border: const OutlineInputBorder(),
                  hintText: '例: ${widget.quest.suggestedOffering}',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '金額を入力せよ';
                  final amount = int.tryParse(value);
                  if (amount == null || amount <= 0) return '有効な金額を入力せよ';
                  if (amount > widget.player.hp) return '残高（¥${widget.player.hp}）を超える支出はできぬ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 用途入力
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: '用途',
                  border: OutlineInputBorder(),
                  hintText: '例: 友人との食事',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '用途を入力せよ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 一言メモ
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '一言メモ（任意）',
                  border: OutlineInputBorder(),
                  hintText: '嬉しかったこと、気づいたこと…',
                ),
              ),
              const SizedBox(height: 32),
              // 残高情報
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('現在の残高: ', style: TextStyle(color: colorScheme.outline)),
                    Text(
                      '¥${widget.player.hp}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.player.isPinchState
                            ? colorScheme.error
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 提出ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('支出を実行する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

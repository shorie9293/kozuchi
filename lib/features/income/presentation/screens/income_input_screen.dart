import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/player_model.dart';

/// 収入記録結果
class IncomeResult {
  final int amount;
  final String source;
  final String note;
  final PlayerModel updatedPlayer;

  IncomeResult({
    required this.amount,
    required this.source,
    required this.note,
    required this.updatedPlayer,
  });
}

/// 収入入力画面
///
/// 支出入力（OfferingInputScreen）と対になる、
/// 収入・残高調整のための入力フォーム。
class IncomeInputScreen extends StatefulWidget {
  final PlayerModel player;

  const IncomeInputScreen({super.key, required this.player});

  @override
  State<IncomeInputScreen> createState() => _IncomeInputScreenState();
}

class _IncomeInputScreenState extends State<IncomeInputScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _sourceController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _sourceController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountController.text);
    final updatedPlayer = widget.player.addHp(amount);
    Navigator.of(context).pop(IncomeResult(
      amount: amount,
      source: _sourceController.text,
      note: _noteController.text,
      updatedPlayer: updatedPlayer,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('収入の記録')),
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
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '巡り来たる金は縁なり。その由縁を記し、感謝の念をもって受け取れ。',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 金額入力
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '収入金額（円）',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(),
                  hintText: '例: 30000',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '金額を入力せよ';
                  final amount = int.tryParse(value);
                  if (amount == null || amount <= 0) return '有効な金額を入力せよ';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 収入源入力
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: '収入源',
                  border: OutlineInputBorder(),
                  hintText: '例: 給与、副業、贈与',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '収入源を入力せよ';
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
                  hintText: '感謝の言葉、使い道の決意…',
                ),
              ),
              const SizedBox(height: 32),

              // 現在残高表示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('現在の残高: ',
                        style: TextStyle(color: colorScheme.outline)),
                    Text(
                      '¥${widget.player.hp}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
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
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                  ),
                  child: const Text('収入を記録する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

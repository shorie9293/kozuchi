import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';

/// 振り返り入力画面
///
/// 喜捨を実行した後の振り返り文を入力する。
/// 内省の深さがSATORI増加量に影響する。
class ReflectionScreen extends StatefulWidget {
  final TrialQuest quest;

  const ReflectionScreen({super.key, required this.quest});

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reflectionController;

  @override
  void initState() {
    super.initState();
    _reflectionController = TextEditingController();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_reflectionController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('振り返り')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 指示文
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(widget.quest.guardianDeity.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.quest.guardianDeity.label}の問い',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'その喜捨は、お主の心に何を残したか？'
                            '金が巡った先に思いを馳せ、素直に綴れ。',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 喜捨情報
              if (widget.quest.offeringAmount != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今回の喜捨',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('金額: ¥${widget.quest.offeringAmount}'),
                      if (widget.quest.offeringPurpose != null)
                        Text('用途: ${widget.quest.offeringPurpose}'),
                      if (widget.quest.offeringNote != null && widget.quest.offeringNote!.isNotEmpty)
                        Text('メモ: ${widget.quest.offeringNote}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 振り返り入力
              TextFormField(
                controller: _reflectionController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: '振り返りを綴れ',
                  border: const OutlineInputBorder(),
                  hintText: '例: 友人との食事で奢った。最初は痛かったが、相手が喜ぶ姿を見て自分の心も軽くなった。',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '振り返りを入力せよ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // ヒント
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '深い内省ほど多くのSATORIを得られる',
                        style: TextStyle(fontSize: 12, color: colorScheme.tertiary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 提出ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('振り返りを提出する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

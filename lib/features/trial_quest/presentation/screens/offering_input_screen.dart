import 'package:flutter/material.dart';
import 'package:kozuchi/domain/models/trial_quest.dart';
import 'package:kozuchi/domain/models/player_model.dart';
import 'package:kozuchi/domain/classifier/classifier_service.dart';
import 'package:kozuchi/features/category_ledger/data/category_ledger_repository.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger.dart';
import 'package:kozuchi/features/category_ledger/domain/category_ledger_service.dart';
import 'package:kozuchi/features/quick_template/data/quick_template_repository.dart';
import 'package:kozuchi/features/quick_template/domain/models/expense_template.dart';
import 'package:kozuchi/features/quick_template/domain/quick_template_service.dart';
import 'package:kozuchi/features/quick_template/presentation/widgets/quick_template_bar.dart';
import 'package:kozuchi/features/receipt_scanner/data/receipt_ocr_service.dart';
import 'package:kozuchi/features/receipt_scanner/data/mlkit_receipt_ocr_service.dart';
import 'package:kozuchi/features/receipt_scanner/presentation/screens/receipt_scanner_screen.dart';

/// 支出入力結果
class OfferingResult {
  final int amount;
  final String purpose;
  final String note;
  final String? receiptImagePath;
  final String? category;
  final PlayerModel updatedPlayer;

  OfferingResult({
    required this.amount,
    required this.purpose,
    required this.note,
    this.receiptImagePath,
    this.category,
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

  /// クイックテンプレートの永続化先（省略時は SharedPreferences 実装）。
  final QuickTemplateRepository? templateRepository;

  /// カテゴリ台帳の永続化先（省略時は SharedPreferences 実装）。
  final CategoryLedgerRepository? categoryLedgerRepository;

  const OfferingInputScreen({
    super.key,
    required this.quest,
    required this.player,
    this.templateRepository,
    this.categoryLedgerRepository,
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
  String? _selectedCategory;
  List<ExpenseTemplate> _templates = [];
  late final QuickTemplateRepository _templateRepository;

  /// カテゴリ台帳から読み込んだ選択肢（読込完了までは既定カテゴリ）
  List<String> _categories = CategoryLedger.defaults().categories;

  /// 読み込んだカテゴリ台帳（自動分類名を正準名へ寄せるのに使う）
  CategoryLedger _ledger = CategoryLedger.defaults();
  late final CategoryLedgerRepository _categoryLedgerRepository;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.quest.suggestedOffering.toString(),
    );
    _purposeController = TextEditingController();
    _noteController = TextEditingController();
    // 用途入力に応じて自動分類
    _purposeController.addListener(_autoClassify);
    _templateRepository = widget.templateRepository ??
        const SharedPreferencesQuickTemplateRepository();
    _categoryLedgerRepository = widget.categoryLedgerRepository ??
        const SharedPreferencesCategoryLedgerRepository();
    _loadTemplates();
    _loadCategories();
  }

  /// カテゴリ台帳を読み込む（破損時は台帳側が既定へフォールバックする）
  Future<void> _loadCategories() async {
    try {
      final ledger = await _categoryLedgerRepository.loadLedger();
      if (!mounted) return;
      setState(() {
        _ledger = ledger;
        _categories = ledger.categories;
      });
    } catch (_) {
      // 例外は画面に漏らさず暫定表示のままにする
    }
  }

  /// クイックテンプレートを読み込む。
  Future<void> _loadTemplates() async {
    final templates = await _templateRepository.loadTemplates();
    if (!mounted) return;
    setState(() => _templates = templates);
  }

  /// テンプレート適用: 入力欄へ流し込み、使用記録を更新する。
  Future<void> _applyTemplate(ExpenseTemplateDraft draft) async {
    setState(() {
      _amountController.text = draft.amount.toString();
      _purposeController.text = draft.purpose;
      _selectedCategory = draft.category;
    });
    if (_templates.isEmpty) return;
    final target = _templates.firstWhere(
      (t) =>
          t.amount == draft.amount &&
          t.purpose == draft.purpose &&
          t.category == draft.category,
      orElse: () => _templates.first,
    );
    final used = QuickTemplateService.applyTemplate(target, DateTime.now());
    final updated = QuickTemplateService.upsert(_templates, used);
    await _templateRepository.saveTemplates(updated);
    if (!mounted) return;
    setState(() => _templates = updated);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 用途テキストから自動分類
  void _autoClassify() {
    final text = _purposeController.text;
    if (text.length >= 2 && _selectedCategory == null) {
      final result = ClassifierService.instance.classify(text);
      if (result.isClassified) {
        // 分類辞書の語尾（例: 交通）を台帳の正準名（例: 交通費）へ寄せる。
        // 寄せないと取引が台帳に無い孤立カテゴリとして記録される。
        final resolved = const CategoryLedgerService()
                .resolveName(_ledger, result.category) ??
            result.category;
        setState(() => _selectedCategory = resolved);
      }
    }
  }

  /// レシート撮影画面を開く
  Future<void> _openReceiptScanner() async {
    final result = await Navigator.of(context).push<ReceiptOcrResult>(
      MaterialPageRoute(
        builder: (_) => ReceiptScannerScreen(
          ocrService: MlKitReceiptOcrService(),
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
      category: _selectedCategory,
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

              // クイックテンプレート（よく使う支出のワンタップ登録）
              QuickTemplateBar(
                templates: QuickTemplateService.frequentTemplates(_templates),
                onSelected: _applyTemplate,
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
              // カテゴリ選択
              Text('カテゴリ',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colorScheme.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) => ChoiceChip(
                  label: Text(
                      '${CategoryLedgerService().emojiFor(cat)} $cat',
                      style: const TextStyle(fontSize: 13)),
                  selected: _selectedCategory == cat,
                  selectedColor:
                      colorScheme.primaryContainer,
                  onSelected: (selected) {
                    setState(() =>
                        _selectedCategory = selected ? cat : null);
                  },
                )).toList(),
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

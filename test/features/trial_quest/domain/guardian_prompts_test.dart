import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/domain/models/advisor.dart';
import 'package:kozuchi/features/trial_quest/data/deepseek_review_service.dart';

void main() {
  group('AdvisorPrompts', () {
    late DeepSeekReviewService service;

    setUp(() {
      service = DeepSeekReviewService();
    });

    test('大黒天のシステムプロンプトに名前と領分が含まれる', () {
      final prompt = service.buildSystemPrompt(Advisor.daikokuten);
      expect(prompt, contains('大黒天'));
      expect(prompt, contains('福・食・財'));
      expect(prompt, contains('〜ぞ'));
      expect(prompt, contains('EXP'));
    });

    test('弁財天のシステムプロンプトに名前と領分が含まれる', () {
      final prompt = service.buildSystemPrompt(Advisor.benzaiten);
      expect(prompt, contains('弁財天'));
      expect(prompt, contains('学び・芸術'));
      expect(prompt, contains('〜わ'));
      expect(prompt, contains('EXP'));
    });

    test('毘沙門天のシステムプロンプトに名前と領分が含まれる', () {
      final prompt = service.buildSystemPrompt(Advisor.bishamonten);
      expect(prompt, contains('毘沙門天'));
      expect(prompt, contains('戦い・勝負'));
      expect(prompt, contains('〜だ'));
      expect(prompt, contains('EXP'));
    });

    test('吉祥天のシステムプロンプトに名前と領分が含まれる', () {
      final prompt = service.buildSystemPrompt(Advisor.kichijoten);
      expect(prompt, contains('吉祥天'));
      expect(prompt, contains('美・幸福'));
      expect(prompt, contains('〜なさい'));
      expect(prompt, contains('EXP'));
    });

    test('各アドバイザーで異なるシステムプロンプトが生成される', () {
      final prompts = Advisor.values.map((d) => service.buildSystemPrompt(d)).toSet();
      // 4柱それぞれ異なるプロンプト
      expect(prompts.length, 4);
    });

    test('ユーザーメッセージに振り返りと支出情報が含まれる', () {
      final message = service.buildUserMessage(
        reflection: '相手が喜んでくれて嬉しかった',
        offeringAmount: 3000,
        offeringPurpose: '友人との食事',
      );
      expect(message, contains('相手が喜んでくれて嬉しかった'));
      expect(message, contains('3000円'));
      expect(message, contains('友人との食事'));
    });
  });
}

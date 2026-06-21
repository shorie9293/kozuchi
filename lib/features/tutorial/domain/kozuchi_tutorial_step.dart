/// チュートリアルステップ定義
enum KozuchiTutorialStep {
  welcome,      // 打ち出の小槌とは
  advisor,     // アドバイザー選択の説明
  offering,     // 支出の概念
  exp,       // EXPと開眼
  complete,     // 完了
}

/// ステップごとの情報
extension KozuchiTutorialStepX on KozuchiTutorialStep {
  String get label {
    switch (this) {
      case KozuchiTutorialStep.welcome:
        return '打ち出の小槌へようこそ';
      case KozuchiTutorialStep.advisor:
        return 'アドバイザーとの契約';
      case KozuchiTutorialStep.offering:
        return '支出の理';
      case KozuchiTutorialStep.exp:
        return '悟りへの道';
      case KozuchiTutorialStep.complete:
        return '旅立ち';
    }
  }

  String get description {
    switch (this) {
      case KozuchiTutorialStep.welcome:
        return 'ここは「打ち出の小槌」——\n'
            '金銭を通じて悟りを開く修行の場です。\n'
            '「宵越しの金は持たない」——\n'
            '手放すことで、真の豊かさに目覚めましょう。';
      case KozuchiTutorialStep.advisor:
        return 'まずは四天のアドバイザーから1柱を選び、\n'
            '契約を結んでください。\n'
            'アドバイザーはあなたの修行を見守り、\n'
            '試練を通じて導いてくれます。';
      case KozuchiTutorialStep.offering:
        return '「支出」——それは自発的な手放しです。\n'
            'HP（心の余裕）を減らして支出を行うと、\n'
            'EXP（悟り値）が増加します。\n'
            '減るほどに目が開く——逆転の理です。';
      case KozuchiTutorialStep.exp:
        return 'EXPが一定値に達すると、\n'
            '開眼段階が上昇します。\n'
            '三段階の開眼を経て、\n'
            'あなたは真の悟りへと近づきます。\n\n'
            'アドバイザーから与えられる試練に\n'
            '立ち向かいましょう。';
      case KozuchiTutorialStep.complete:
        return '準備は整いました。\n'
            'さあ、アドバイザーと契約し、\n'
            '修行の第一歩を踏み出しましょう。';
    }
  }

  KozuchiTutorialStep? get next {
    switch (this) {
      case KozuchiTutorialStep.welcome:
        return KozuchiTutorialStep.advisor;
      case KozuchiTutorialStep.advisor:
        return KozuchiTutorialStep.offering;
      case KozuchiTutorialStep.offering:
        return KozuchiTutorialStep.exp;
      case KozuchiTutorialStep.exp:
        return KozuchiTutorialStep.complete;
      case KozuchiTutorialStep.complete:
        return null;
    }
  }
}

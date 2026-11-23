import 'package:flutter/services.dart';

/// 入力欄の意味に応じた長さ上限を一元管理する。
///
/// kozuchi は取引を 1 本の JSON 文字列へ保存する設計のため、
/// 無制限の入力は保存データの肥大・破損に直結する。
/// 画面ごとに数値を散らさず、欄の意味ごとにここで定義して共有する。
///
/// 使い方:
/// ```dart
/// TextFormField(
///   controller: _amountController,
///   inputFormatters: InputLimits.amount,
/// )
/// ```
///
/// カウンタ表示によるレイアウト変化を避けるため、`maxLength` ではなく
/// [LengthLimitingTextInputFormatter] を用いる（`maxLength` は付けない）。
class InputLimits {
  const InputLimits._();

  /// 金額（円）。9 桁 = 10 億円未満。
  static const int amountMaxLength = 9;

  /// 日・請求日（1〜31）。
  static const int dayMaxLength = 2;

  /// 分割回数などの回数。
  static const int countMaxLength = 3;

  /// 名称（カテゴリ・タグ・財布名・収入源・名称など）。
  static const int nameMaxLength = 50;

  /// 用途・ラベル（短い説明文）。
  static const int labelMaxLength = 100;

  /// 単一行メモ。
  static const int noteMaxLength = 200;

  /// 複数行メモ。
  static const int memoMaxLength = 1000;

  /// 振り返り（長文）。
  static const int reflectionMaxLength = 2000;

  /// 検索キーワード。
  static const int searchMaxLength = 100;

  /// 金額欄（数字のみ）。桁区切り・全角を受け付けない厳格な欄向け。
  static final List<TextInputFormatter> amount = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(amountMaxLength),
  ];

  /// 金額欄（IME 寛容）。
  ///
  /// [AmountParser] が全角数字・桁区切り・マイナスを解釈する欄では、
  /// 数字以外を弾くと検証メッセージ（「数字で入力してください」）が
  /// 「入力してください」へ化けてしまう。長さ上限のみを課す。
  static final List<TextInputFormatter> amountTolerant = <TextInputFormatter>[
    LengthLimitingTextInputFormatter(amountMaxLength),
  ];

  /// 日・請求日欄（数字のみ 2 桁）。
  static final List<TextInputFormatter> day = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(dayMaxLength),
  ];

  /// 回数欄（数字のみ 3 桁）。
  static final List<TextInputFormatter> count = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(countMaxLength),
  ];

  /// 名称欄（50 文字）。
  static final List<TextInputFormatter> name = <TextInputFormatter>[
    LengthLimitingTextInputFormatter(nameMaxLength),
  ];

  /// 用途・ラベル欄（100 文字）。
  static final List<TextInputFormatter> label = <TextInputFormatter>[
    LengthLimitingTextInputFormatter(labelMaxLength),
  ];

  /// 単一行メモ欄（200 文字）。
  static final List<TextInputFormatter> note = <TextInputFormatter>[
    LengthLimitingTextInputFormatter(noteMaxLength),
  ];

  /// 複数行メモ欄（1000 文字）。
  static final List<TextInputFormatter> memo = <TextInputFormatter>[
    LengthLimitingTextInputFormatter(memoMaxLength),
  ];

  /// 振り返り欄（2000 文字）。
  static final List<TextInputFormatter> reflection = <TextInputFormatter>[
    LengthLimitingTextInputFormatter(reflectionMaxLength),
  ];

  /// 検索キーワード欄（100 文字）。
  static final List<TextInputFormatter> search = <TextInputFormatter>[
    LengthLimitingTextInputFormatter(searchMaxLength),
  ];
}

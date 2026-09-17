import 'package:flutter/material.dart';

/// レシート閲覧機能の試練用 Key（KozuchiAppKeys とは別ファイル・別クラス）。
///
/// AppKeys は機能ごとに分離する慣習。既存クラスへの追加分が
/// アナライザから不可視になる禍津を避けるため、新規は必ず別ファイルにする。
class ReceiptViewerAppKeys {
  const ReceiptViewerAppKeys._();

  /// レシート閲覧画面全体。
  static const Key viewerScreen = Key('receiptViewerScreen');

  /// 表示されたレシート画像。
  static const Key viewerImage = Key('receiptViewerImage');

  /// ローディング表示。
  static const Key viewerLoading = Key('receiptViewerLoading');

  /// 画像が見つからない／パス不正の空状態。
  static const Key viewerEmpty = Key('receiptViewerEmpty');

  /// 空状態のメッセージ。
  static const Key viewerErrorMessage = Key('receiptViewerErrorMessage');

  /// 再読込ボタン。
  static const Key viewerRetryButton = Key('receiptViewerRetryButton');

  /// 取引リスト項目のレシートボタン（日時と金額から一意に決まる）。
  static Key receiptButtonFor(String datetime, int amount) =>
      Key('receiptButton_${datetime}_$amount');

  /// レシート閲覧画面のタイトル。
  static const Key viewerTitle = Key('receiptViewerTitle');
}

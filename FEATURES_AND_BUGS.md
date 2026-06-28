# kozuchi（小槌） 機能一覧・既知バグ・修正点

> **バージョン**: v1.3.0+35  
> **最終更新**: 2026-06-28  
> **フレームワーク**: Flutter (Dart SDK ^3.6.2)  
> **状態管理**: Riverpod (via takamagahara_ui)  
> **バックエンド**: Supabase (匿名認証 + クラウド同期)  
> **OCR**: Google ML Kit Text Recognition  
> **CI/CD**: GitHub Actions → Google Play (Fastlane)

---

## 目次

1. [全機能一覧](#1-全機能一覧)
2. [画面構成とナビゲーション](#2-画面構成とナビゲーション)
3. [既知のバグ・修正点](#3-既知のバグ修正点)
4. [テスト状況](#4-テスト状況)

---

## 1. 全機能一覧

### 1.1 コアシステム

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 1 | **プレイヤーモデル** | `lib/domain/models/player_model.dart` | HP（残高）、EXP（悟り）、契約アドバイザー、開眼段階、金運バフ、seenStages を保持 |
| 2 | **開眼段階（LevelStage）** | `lib/domain/models/level_stage.dart` | 3段階：初転法輪(Lv1) / 縁起(Lv2) / 空(LvMAX)。EXP値で自動昇格 |
| 3 | **アドバイザー（守護神）** | `lib/domain/models/advisor.dart` | 四柱：大黒天(x1.0) / 弁財天(x1.1) / 毘沙門天(x1.2) / 吉祥天(x1.0)。各神にEXP倍率あり |
| 4 | **支出分類器** | `lib/domain/classifier/` | キーワードベース + 設定可能JSONルールで支出をカテゴリ自動分類 |
| 5 | **ストリーク（連続記録）** | `lib/domain/streak/` | 連続支出記録のトラッキング、HungryZone（節約ゾーン）状態管理 |
| 6 | **守護神切替サービス** | `lib/domain/services/guardian_switch_service.dart` | 守護神切替時のEXP消費・クールダウン（7日）・エラー処理 |
| 7 | **支出集計サービス** | `lib/domain/services/expense_aggregation_service.dart` | 支出データの集計・分析ロジック |
| 8 | **支出リポジトリ** | `lib/domain/services/expense_repository.dart` | 支出データの永続化インターフェース |
| 9 | **金運バフ（GoldLuckBuff）** | `lib/domain/models/gold_luck_buff.dart` | 積読読了等による収入倍率バフ（期間限定） |

### 1.2 インフラ・基盤

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 10 | **匿名認証** | `lib/core/infrastructure/auth_service.dart` | Supabase匿名サインイン。オフライン時はフォールバック |
| 11 | **Supabase初期化** | `lib/core/infrastructure/supabase_provider.dart` | Supabaseクライアント設定・プロバイダ |
| 12 | **環境変数** | `lib/core/infrastructure/env.dart` | `.env` からの環境変数読込（API URL等） |
| 13 | **ディープリンク** | `lib/core/infrastructure/deep_link_service.dart` | app://weekly-report?week=YYYY-WW 形式のリンク処理 |
| 14 | **クラウド同期** | `lib/core/infrastructure/cloud_sync_service.dart` | Supabase経由のデータ同期。最終書き込み優先の競合解決 |
| 15 | **テーマ管理** | `lib/core/theme/app_theme.dart` | Light/Dark/System 3モードのテーマ。墨インク背景・金アクセント |
| 16 | **テーマ保存** | `lib/core/theme/theme_repository.dart` | SharedPreferencesにテーマ設定を永続化 |
| 17 | **和紙背景** | `lib/core/widgets/washi_background.dart` | 和紙テクスチャ風の背景Widget |

### 1.3 メイン画面（3タブレイアウト）

| # | 機能 | 説明 |
|---|------|------|
| 18 | **🎯 目標タブ** | EXPゲージ + クイックリンク（予算設定/実績/貯蓄目標/取引履歴/支出分析/アプリ連携）+ 裏面モード |
| 19 | **📜 試練タブ** | 守護神祝福ライン + 試練カード + デイリークエスト一覧 |
| 20 | **🛡️ 加護タブ** | 守護神詳細カード（切替ボタン）+ テーマ切替 + 開眼段階バッジ |
| 21 | **支出FAB** | 常時表示の支出記録フローティングアクションボタン（HP削除後の代替） |
| 22 | **目標支出ゲージ** | 画面上部に常時表示。月次予算消化率を可視化 |

### 1.4 予算管理 (budget)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 23 | **予算設定画面** | `lib/features/budget/presentation/screens/budget_settings_screen.dart` | 月次予算額・警告閾値の設定 |
| 24 | **日次予算計算** | `lib/features/budget/data/daily_budget_service.dart` | 月次予算から日次許容量を算出 |
| 25 | **予算警告バナー** | `lib/features/budget/presentation/widgets/budget_warning_banner.dart` | 予算超過率が閾値を超えたら警告表示 |
| 26 | **日次予算Widget** | `lib/features/budget/presentation/widgets/daily_budget_widget.dart` | 日次予算の表示コンポーネント |
| 27 | **月次支出リポジトリ** | `lib/features/budget/data/monthly_spending_repository.dart` | 月次支出データの永続化 |

### 1.5 目標支出 (goal_spending)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 28 | **目標支出ゲージ** | `lib/features/goal_spending/presentation/widgets/goal_spending_gauge.dart` | 支出消化率を棒ゲージで可視化。タップで予算設定画面へ |

### 1.6 試練クエスト (trial_quest)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 29 | **試練クエスト画面** | `lib/features/trial_quest/presentation/screens/trial_quest_screen.dart` | 守護神からの試練（支出目標）の遂行画面 |
| 30 | **支出入力画面** | `lib/features/trial_quest/presentation/screens/offering_input_screen.dart` | 金額・カテゴリ選択UI（自動分類＋手動選択） |
| 31 | **講評画面** | `lib/features/trial_quest/presentation/screens/reflection_screen.dart` | 試練完了後の守護神からの講評表示 |
| 32 | **DeepSeek講評** | `lib/features/trial_quest/data/deepseek_review_service.dart` | AIによる支出レビュー生成（DeepSeek API） |
| 33 | **AIレビューIF** | `lib/features/trial_quest/domain/ai_review_service.dart` | AIレビューサービスの抽象インターフェース |

### 1.7 デイリークエスト (daily_quest)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 34 | **デイリークエスト一覧** | `lib/features/daily_quest/presentation/widgets/daily_quest_list.dart` | 本日のクエスト一覧表示 |
| 35 | **デイリークエストカード** | `lib/features/daily_quest/presentation/widgets/daily_quest_card.dart` | 個別クエストの進捗カード |
| 36 | **クエスト達成エフェクト** | `lib/features/daily_quest/presentation/widgets/quest_achievement_effect.dart` | 全クエスト達成時の演出 |
| 37 | **クエストオーケストレーター** | `lib/features/daily_quest/data/daily_quest_orchestrator.dart` | 日次クエストの生成・割当・状態管理 |
| 38 | **クエスト割当サービス** | `lib/features/daily_quest/data/quest_assignment_service.dart` | 予算設定に基づくクエストの動的割当 |
| 39 | **クエスト進捗検出** | `lib/features/daily_quest/data/quest_progress_detector.dart` | 支出アクションからのクエスト進捗自動検出 |
| 40 | **SATORIペナルティ** | `lib/features/daily_quest/presentation/state/daily_quest_notifier.dart` | 日跨ぎ時の未達成クエストによる悟り減少処理 |

### 1.8 週次クエスト (weekly_quest)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 41 | **週次クエスト選択画面** | `lib/features/weekly_quest/presentation/screens/weekly_quest_selection_screen.dart` | 週間クエストの選択UI |
| 42 | **週次クエスト生成** | `lib/features/weekly_quest/data/weekly_quest_generator.dart` | テンプレートベースの週次クエスト自動生成 |
| 43 | **クエストテンプレート** | `lib/features/weekly_quest/data/quest_templates.dart` | 週次クエストのテンプレート定義 |
| 44 | **アクティブ週次クエスト** | `lib/features/weekly_quest/domain/models/active_weekly_quest.dart` | アクティブな週次クエストのモデル |
| 45 | **週次クエスト永続化** | `lib/features/weekly_quest/data/weekly_quest_repository.dart` | 週次クエストの保存・読込 |

### 1.9 実績 (achievements)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 46 | **実績一覧画面** | `lib/features/achievements/presentation/screens/achievement_list_screen.dart` | 全実績の一覧表示（解除状態・進捗） |
| 47 | **実績アンロックオーバーレイ** | `lib/features/achievements/presentation/widgets/achievement_unlock_overlay.dart` | 新実績解除時のポップアップ通知 |
| 48 | **実績APIサービス** | `lib/features/achievements/data/achievement_service.dart` | GET /api/achievements との通信 |
| 49 | **クロスアプリ実績集約** | `lib/features/achievements/data/cross_app_achievement_aggregator.dart` | 他アプリ（rpg-task等）との実績横断集約 |
| 50 | **SATORI可視化** | `lib/features/effects/presentation/effects/` | 闇の帳エフェクト等、SATORI関連ビジュアル |

### 1.10 エフェクト (effects)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 51 | **エフェクトマネージャー** | `lib/features/effects/presentation/effect_manager.dart` | エフェクトの統括管理・発火 |
| 52 | **エフェクトカタログ** | `lib/features/effects/data/effect_catalog.dart` | 全エフェクト定義のカタログ |
| 53 | **コインスキャッター** | `lib/features/effects/presentation/effects/coin_scatter_effect.dart` | 支出記録時のコイン飛散エフェクト |
| 54 | **桜吹雪** | `lib/features/effects/presentation/effects/cherry_blizzard_effect.dart` | 入金時の桜吹雪エフェクト |
| 55 | **悟りグロー** | `lib/features/effects/presentation/effects/satori_glow_effect.dart` | SATORI増加時の発光エフェクト |
| 56 | **悟り増加UI** | `lib/features/effects/presentation/effects/satori_increase_effect.dart` | +N表示の悟り増加エフェクト |
| 57 | **悟りツールチップ** | `lib/features/effects/presentation/effects/satori_tooltip_effect.dart` | EXP詳細説明のツールチップ |
| 58 | **光の柱** | `lib/features/effects/presentation/effects/pillar_of_light_effect.dart` | 開眼昇格時の光の柱エフェクト |
| 59 | **闇の帳** | `lib/features/effects/presentation/effects/dark_curtain_effect.dart` | SATORI低下時の闇の帳エフェクト |
| 60 | **守護神切替エフェクト** | `lib/features/effects/presentation/effects/guardian_switch_effect.dart` | 守護神切替時の演出 |
| 61 | **プレースホルダー** | `lib/features/effects/presentation/effects/placeholder_effect.dart` | 未実装エフェクト用プレースホルダー |
| 62 | **エフェクト定義** | `lib/features/effects/domain/effect_definition.dart` | エフェクトの定義モデル |
| 63 | **エフェクトインスタンス** | `lib/features/effects/domain/effect_instance.dart` | エフェクトの実行時インスタンス |

### 1.11 取引履歴 (transaction_history)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 64 | **取引履歴ページ** | `lib/features/transaction_history/presentation/screens/transaction_history_page.dart` | 全取引の一覧表示 |
| 65 | **取引リストWidget** | `lib/features/transaction_history/presentation/widgets/transaction_list_widget.dart` | 取引リストレンダリング |
| 66 | **取引リスト項目** | `lib/features/transaction_history/presentation/widgets/transaction_list_item.dart` | 個別取引行の表示 |
| 67 | **取引コントローラー** | `lib/features/transaction_history/presentation/state/transaction_controller.dart` | 取引一覧の状態管理 |
| 68 | **取引サービス** | `lib/features/transaction_history/data/transaction_service.dart` | 取引データのCRUD操作 |

### 1.12 取引フィルター (transaction_filter)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 69 | **取引フィルターモデル** | `lib/features/transaction_filter/domain/models/transaction_filter.dart` | カテゴリ・期間等のフィルター条件 |
| 70 | **取引フィルターバー** | `lib/features/transaction_filter/presentation/widgets/transaction_filter_bar.dart` | フィルター操作用UIバー |

### 1.13 分析・チャート

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 71 | **分析チャート** | `lib/features/analysis_chart/presentation/widgets/analysis_chart_widget.dart` | 支出分析グラフ |
| 72 | **支出チャート（日次棒）** | `lib/features/spending_chart/presentation/widgets/daily_bar_chart_widget.dart` | 日次支出棒グラフ |
| 73 | **日次支出データ** | `lib/features/spending_chart/data/daily_spending_data.dart` | 日次支出データモデル |
| 74 | **サマリー画面** | `lib/features/summary_chart/presentation/screens/summary_screen.dart` | 支出サマリー画面 |
| 75 | **カテゴリ円グラフ** | `lib/features/summary_chart/presentation/widgets/category_pie_chart_widget.dart` | カテゴリ別支出の円グラフ |
| 76 | **カテゴリ円データ** | `lib/features/summary_chart/domain/category_pie_data.dart` | 円グラフ用データモデル |
| 77 | **期間比較サマリー** | `lib/features/period_comparison/presentation/widgets/period_comparison_summary.dart` | 前月比等の期間比較 |

### 1.14 EXPゲージ

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 78 | **EXPゲージWidget** | `lib/features/exp_gauge/presentation/widgets/exp_gauge_widget.dart` | コンパクトな悟りゲージ表示 |

### 1.15 HPバー (削除済み)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 79 | **HPバーWidget** | `lib/features/hp_bar/presentation/widgets/hp_bar_widget.dart` | 残高表示HPバー（最新コミットで削除、コードは残存） |

### 1.16 ピンチゾーン (pinch_zone)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 80 | **ピンチゾーンオーバーレイ** | `lib/features/pinch_zone/presentation/widgets/pinch_zone_overlay.dart` | HP低下時のピンチ状態オーバーレイ |
| 81 | **ピンチゾーン警告バナー** | `lib/features/pinch_zone/presentation/widgets/pinch_zone_warning_banner.dart` | 生活防衛ライン（30,000円）を下回った際の警告 |

### 1.17 悟り (satori)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 82 | **SATORI変更検出** | `lib/features/satori/data/satori_change_detector.dart` | EXP値の変化を検出 |
| 83 | **SATORI変更イベント** | `lib/features/satori/domain/satori_change_event.dart` | SATORI変更のドメインイベント |
| 84 | **SATORI理由モデル** | `lib/features/satori/domain/satori_reason.dart` | SATORI変動の理由モデル |
| 85 | **SATORIイベントディスパッチャー** | `lib/features/satori/data/satori_event_dispatcher.dart` | SATORIイベントの配信 |

### 1.18 アドバイザー選択 (advisor_selection)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 86 | **アドバイザー選択画面** | `lib/features/advisor_selection/presentation/advisor_selection_screen.dart` | 四柱から守護神を選択する画面（初回契約・切替共用） |

### 1.19 貯蓄目標 (goals)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 87 | **目標一覧画面** | `lib/features/goals/presentation/screens/goal_list_screen.dart` | 貯蓄目標の一覧表示 |
| 88 | **目標フォーム画面** | `lib/features/goals/presentation/screens/goal_form_screen.dart` | 貯蓄目標の新規作成・編集 |
| 89 | **目標APIサービス** | `lib/features/goals/data/goal_api_service.dart` | 目標APIとの通信 |
| 90 | **目標モデル** | `lib/features/goals/data/goal.dart` | 目標データモデル |

### 1.20 週次レポート (weekly_report)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 91 | **週次レポート画面** | `lib/features/weekly_report/presentation/screens/weekly_report_screen.dart` | 週間支出レポート（ディープリンク対応） |
| 92 | **週次レポートサービス** | `lib/features/weekly_report/data/weekly_report_service.dart` | 週次データ集計 |
| 93 | **週次レポートAPI** | `lib/features/weekly_report/data/weekly_report_api_service.dart` | 週次レポートAPI通信 |
| 94 | **週次レポートモデル** | `lib/features/weekly_report/data/weekly_report.dart` | 週次レポートデータモデル |

### 1.21 レシートスキャン (receipt_scanner)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 95 | **レシートスキャン画面** | `lib/features/receipt_scanner/presentation/screens/receipt_scanner_screen.dart` | カメラでレシートをスキャン |
| 96 | **ML Kit OCRサービス** | `lib/features/receipt_scanner/data/mlkit_receipt_ocr_service.dart` | Google ML Kitによる実OCR認識 |
| 97 | **レシート金額抽出** | `lib/features/receipt_scanner/data/receipt_amount_extractor.dart` | OCRテキストから金額を抽出 |
| 98 | **OCRサービスIF** | `lib/features/receipt_scanner/data/receipt_ocr_service.dart` | OCRサービスの抽象インターフェース |

### 1.22 CSVエクスポート (csv_export)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 99 | **CSVエクスポート画面** | `lib/features/csv_export/presentation/screens/csv_export_screen.dart` | 支出データのCSV出力UI |
| 100 | **CSV生成サービス** | `lib/features/csv_export/data/csv_export_service.dart` | CSVファイル生成ロジック |
| 101 | **Google Drive連携** | `lib/features/csv_export/data/drive_upload_service.dart` | CSVのGoogle Driveアップロード |

### 1.23 収入管理 (income)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 102 | **収入入力画面** | `lib/features/income/presentation/screens/income_input_screen.dart` | 収入（給与等）の記録画面 |

### 1.24 積読連携 (tsundoku)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 103 | **金運バフサービス** | `lib/features/tsundoku/data/tsundoku_gold_luck_buff_service.dart` | 積読アプリ読了イベントを監視し金運バフを付与 |

### 1.25 キャリアコーチ連携 (careerCoach)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 104 | **蔵書ボーナスサービス** | `lib/features/careerCoach/data/careerCoach_book_bonus_service.dart` | 弁財天契約時に蔵書追加でEXPボーナス |

### 1.26 RPGタスク連携 (rpg_task_bonus)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 105 | **討伐ボーナスサービス** | `lib/features/rpg_task_bonus/data/rpg_task_bonus_service.dart` | rpg-taskからの討伐イベントを監視しEXPボーナス |
| 106 | **ボーナスログリポジトリ** | `lib/features/rpg_task_bonus/data/rpg_task_bonus_log_repository.dart` | ボーナス付与履歴の永続化 |

### 1.27 チュートリアル (tutorial)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 107 | **チュートリアルオーバーレイ** | `lib/features/tutorial/presentation/kozuchi_tutorial_overlay.dart` | 初回起動時のガイドオーバーレイ |
| 108 | **チュートリアルステップ** | `lib/features/tutorial/domain/kozuchi_tutorial_step.dart` | チュートリアル進行ステップ定義 |
| 109 | **チュートリアルサービス** | `lib/features/tutorial/data/kozuchi_tutorial_service.dart` | 初回起動判定・完了マーク |

### 1.28 コラボレーションダッシュボード (collaboration_dashboard)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 110 | **アプリ連携ダッシュボード** | `lib/features/collaboration_dashboard/presentation/screens/collaboration_dashboard_screen.dart` | 他アプリ（rpg-task, tsundoku-quest等）との連携状態表示 |
| 111 | **連携統計サービス** | `lib/features/collaboration_dashboard/data/collaboration_stats_service.dart` | 連携アプリの統計データ取得 |

### 1.29 共有データ層 (shared)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 112 | **PlayerRepository** | `lib/features/shared/data/player_repository.dart` | プレイヤー状態のSharedPreferences永続化 |
| 113 | **ExpenditureRepository** | `lib/features/shared/data/expenditure_repository.dart` | 支出データの永続化 |
| 114 | **BudgetRepository** | `lib/features/shared/data/budget_repository.dart` | 予算設定の永続化 |
| 115 | **クエストエクスポーター** | `lib/features/shared/data/kozuchi_quest_exporter.dart` | 他アプリ連携用クエストデータのJSONエクスポート |

### 1.30 開眼トランジション (enlightenment)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 116 | **開眼アニメーション** | `lib/features/enlightenment/presentation/enlightenment_transition_overlay.dart` | 開眼段階昇格時の全画面アニメーション（曼荼羅展開/世界反転） |

### 1.31 ストリーク (streak)

| # | 機能 | ファイル | 説明 |
|---|------|---------|------|
| 117 | **ストリークオーケストレーター** | `lib/features/streak/streak_orchestrator.dart` | 連続記録のオーケストレーション |
| 118 | **ストリーク永続化** | `lib/features/streak/data/streak_persistence_impl.dart` | ストリークデータの保存・読込 |

### 1.32 裏面モード (マスター領域)

| # | 機能 | 説明 |
|---|------|------|
| 119 | **分析チャート** | 裏面（空段階到達時開放）での詳細分析チャート表示 |
| 120 | **期間比較** | 裏面での前月比等の期間比較サマリー表示 |

---

## 2. 画面構成とナビゲーション

```
MainScreen (打ち出の小槌)
├── GoalSpendingGauge (固定ヘッダー: 目標支出ゲージ)
├── PinchZoneWarningBanner / BudgetWarningBanner (条件付き警告)
├── TabBar [🎯目標, 📜試練, 🛡️加護]
│   ├── 🎯 Goalタブ
│   │   ├── ExpGauge (コンパクトEXPゲージ)
│   │   ├── 予算設定ボタン → BudgetSettingsScreen
│   │   ├── 実績ボタン → AchievementListScreen
│   │   ├── 貯蓄目標ボタン → GoalListScreen
│   │   ├── 取引履歴ボタン → TransactionHistoryPage
│   │   ├── 支出分析ボタン → SummaryScreen
│   │   ├── アプリ連携ボタン → CollaborationDashboardScreen
│   │   └── 裏面モード (空段階開放): AnalysisChart + PeriodComparisonSummary
│   ├── 📜 試練タブ
│   │   ├── 守護神祝福ライン
│   │   ├── 試練カード → TrialQuestScreen
│   │   │   └── OfferingInputScreen (支出入力)
│   │   │   └── ReflectionScreen (講評)
│   │   └── デイリークエスト一覧 → DailyQuestList
│   └── 🛡️ 加護タブ
│       ├── 守護神詳細カード
│       │   └── 守護神切替 → AdvisorSelectionScreen
│       ├── テーマ切替 (Light/Dark/System)
│       └── 開眼段階バッジ
└── FAB (支出記録: 常時表示)
    └── TrialQuestScreen (簡易/既存クエスト)

その他画面:
├── WeeklyReportScreen (ディープリンク: app://weekly-report?week=YYYY-WW)
├── ReceiptScannerScreen (ML Kit OCR)
├── CsvExportScreen (CSV出力 + Drive連携)
├── IncomeInputScreen (収入記録)
├── WeeklyQuestSelectionScreen (週次クエスト選択)
└── BudgetSettingsScreen (予算設定)
```

---

## 3. 既知のバグ・修正点

### 3.1 コード上の問題点

| # | カテゴリ | 問題 | ファイル | 詳細 |
|---|---------|------|---------|------|
| B1 | ⚠️ 警告 | **分析通過後に新規警告が発生する可能性** | 全般 | `flutter analyze --no-fatal-infos` で警告が CI のプッシュゲートをブロック。新規コード追加時は常にanalyze通過確認が必要 |
| B2 | 🐛 バグ | **未使用変数 quests** | `lib/features/...` | コミット `1266418` で削除済み（`fix: remove unused local variable quests`） |
| B3 | 🐛 バグ | **null-aware式のデッドコード** | 未特定 | コミット `0cc3ac2` で修正済み（`fix: remove dead null-aware expression in getExpenseCount`） |
| B4 | ⚠️ 未実装 | **criteria_type 未実装の進捗表示** | `lib/features/achievements/presentation/screens/achievement_list_screen.dart:246` | 実績画面で、進捗情報がない場合の表示（criteria_typeが未実装の場合） |
| B5 | 🐛 バグ | **fl_chart未導入時のビルドエラー** | 依存関係 | コミット `5290213` で修正済み（`fix: add fl_chart dependency to resolve 33 build errors`）。v1.0.3+24 で対応 |
| B6 | 🐛 バグ | **テーマの可読性問題** | テーマファイル | コミット `144d644` で修正済み（`fix: theme readability - switch to TakamagaharaTheme for high contrast text`） |
| B7 | ⚠️ 注意 | **ダークモード最適化（履歴）** | テーマファイル | コミット `9a3bb85` で修正済み：墨インク背景・金アクセントへの色調統一、ハードコードカラーの修正 |
| B8 | 🐛 バグ | **Android ProGuard設定** | `android/` | コミット `a0782f3` で修正済み（ML Kit R8 ProGuard rules） |
| B9 | 🐛 バグ | **CI設定の鍵管理問題** | `.github/workflows/deploy.yml` | 複数コミットで修正：鍵デコード問題（`b72d681`）、設定パス問題（`3ba33ce`, `45fa616`）、空ファイル対応（`5aab2c2`） |
| B10 | 🐛 バグ | **環境変数未配置問題** | CI/CD | コミット `527f3d3` で修正済み（`.env` をビルドアセットに追加 + CI環境変数注入） |
| B11 | ⚠️ 注意 | **2つのテストが未修正** | テスト | コミット `7785d5f` にて「WIP - 2 tests need fix」と明記。実績画面リファクタリング後のテスト未修正 |
| B12 | ⚠️ 注意 | **エージェント破棄による不完全な機能（履歴）** | 複数ファイル | コミット `027af7b` にて、クラッシュしたエージェント実行からの不完全な機能をスカッシュ。P2-P5の生成機能を含む |
| B13 | ⚠️ 注意 | **孤立テストファイル** | `test/` | コミット `4bddc47` にて削除済み（クラッシュエージェント実行からの孤立テストファイル） |
| B14 | 🔧 修正済 | **Gradleバージョン問題** | `android/gradle/` | コミット `bd53d8d` / `7408768` にて修正：Gradle 8.3→8.11.1、AGP 8.1.0→8.9.1、Kotlin 1.8.22→2.0.21 |

### 3.2 最新コミットでの主な変更 (6afaf24 / 2dea2a5)

| 変更 | 内容 |
|------|------|
| **タブレイアウト化** | メイン画面を3タブ（目標/試練/加護）に再構成 |
| **HP削除** | 銀行残高（HP）表示を画面上部から削除（メイン画面の`hp_bar`非表示化） |
| **支出FAB常時表示** | 支出記録ボタンを常時表示のFABとして維持 |
| **クラウド同期競合解決** | 最終書き込み優先（last-write-wins）の競合解決を実装 |
| **テスト追加** | FakeSupabaseServerを使用したクラウド同期統合テスト28件を追加 |

### 3.3 既知の制約・制限

| # | 制約 | 詳細 |
|---|------|------|
| C1 | **analyze警告=CI失敗** | `flutter analyze --no-fatal-infos` はinfoのみ抑制。warningはCI/プッシュゲートをブロックする |
| C2 | **モノレポパッケージ依存** | `takamagahara_ui` は `../../packages/` からの相対パス。CIではGitHubから別途クローン |
| C3 | **flutter_dotenv必須** | `.env` ファイルがビルド時に必須。CIではGitHub Secretsから生成 |
| C4 | **匿名認証オフラインフォールバック** | Supabase匿名認証失敗時もアプリ起動は継続するが、クラウド同期は不可 |
| C5 | **Google ML KitはAndroid実機必須** | ML Kitテキスト認識はAndroid実機が必要（エミュレータでは動作しない可能性） |
| C6 | **tsundoku連携は共有ストレージ依存** | `/data/local/tmp/takamagahara_shared/` を介したファイルベース連携。ファイル不存在時は機能しない |
| C7 | **B4: criteria_typeの未実装ケース** | 実績画面の一部進捗表示ロジックで未実装ケースが存在 |
| C8 | **B11: 2テストが未修正** | コミット `7785d5f` 時点で2テストが修正未完了。現在も未修正の可能性 |

---

## 4. テスト状況

| メトリクス | 値 |
|-----------|-----|
| テストファイル数 | ~70+（統合テスト含む） |
| テストケース数 | 〜300程度（過去のログに214件とあり、その後増加） |
| 統合テスト | 28件（FakeSupabaseServerを使用したクラウド同期テスト） |
| カバレッジ計測 | CIで実行（`flutter test --coverage`） |
| 主なテスト対象 | 全ドメインモデル、全リポジトリ、全サービス、主要画面Widget |

### テストファイル一覧（代表）

| テスト対象 | ファイル |
|-----------|---------|
| クラウド同期 | `test/core/infrastructure/cloud_sync_service_test.dart`, `cloud_sync_integration_test.dart` |
| プレイヤーモデル | `test/domain/models/player_model_test.dart` |
| アドバイザー | `test/domain/models/advisor_test.dart` |
| 開眼段階 | `test/domain/models/level_stage_test.dart` |
| 試練クエスト | `test/features/trial_quest/trial_quest_screen_test.dart` |
| 支出入力画面 | `test/features/trial_quest/presentation/screens/offering_input_screen_test.dart` |
| 講評画面 | `test/features/trial_quest/presentation/screens/reflection_screen_test.dart` |
| アドバイザー選択 | `test/features/advisor_selection/advisor_selection_screen_test.dart` |
| 実績サービス | `test/features/achievements/data/achievement_service_test.dart` |
| デイリークエスト | `test/features/daily_quest/data/quest_assignment_service_test.dart` |
| 守護神切替 | `test/domain/services/guardian_switch_service_test.dart` |
| チュートリアル | `test/features/tutorial/` (3ファイル) |
| コラボダッシュボード | `test/features/collaboration_dashboard/presentation/screens/collaboration_dashboard_screen_test.dart` |
| 分類器 | `test/domain/classifier/` (2ファイル) |
| SATORI | `test/features/satori/` (2ファイル) |
| CSVエクスポート | `test/features/csv_export/data/csv_export_service_test.dart` |
| 取引コントローラー | `test/features/transaction_history/presentation/state/transaction_controller_test.dart` |

---

## 凡例

| 記号 | 意味 |
|------|------|
| 🟢 | 実装完了・正常動作 |
| ⚠️ | 注意が必要（未実装部分あり/制約あり） |
| 🐛 | バグ（修正済みのもの含む） |
| 🔧 | 修正済み |
| 📌 | 特に注意すべき制約 |

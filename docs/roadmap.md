# 【Kozuchi（打ち出の小槌）道標】

**制定**: 令和八年皐月十二日
**元神想書**: `shinsho/kozuchi-concept.md`
**試験**: 173/173通過 ✅ / dart analyze clean ✅
**改訂**: 令和八年皐月三十日 午後 — 試験数実測 173に更新（widget_test非同期ロード待ち修正で171→173）

---

## 現状

| 要素 | 状態 |
|------|------|
| Flutterプロジェクト | ✅ Feature-First構造 |
| HPバー（銀行残高連動） | ✅ |
| SATORIゲージ | ✅ |
| 守護神（四天）選択 | ✅ 1柱選択 |
| 試練（喜捨クエスト）発行 | ✅ |
| 喜捨入力（手動） | ✅ |
| 開眼三段階（初転法輪→縁起→空） | ✅ 基本実装 |
| LLM守護神AI講評 | ✅ DeepSeek API連携・四天個別プロンプト・SATORI倍率動的調整 |
| レシート撮影（拡張2） | ✅ ReceiptScannerScreen + OCR + 金額・店名自動抽出 |

---

## 優先タスク（優先度順）

### ✅ 拡張1: LLM守護神AI講評（皐月十四日 昼前 完了）
- [x] DeepSeek API 連携（FakeClientテスト対応）
- [x] 振り返り文→守護神AIが神仏習合文体で講評
- [x] SATORI変動量を内省の深さで変動（AI評価倍率0.5〜2.0）
- [x] 守護神ごとに異なる文体（大黒天／毘沙門天／弁財天／吉祥天）

### 🔴 拡張2: レシート撮影 ✅（皐月十六日 夕刻——イシコリ）
- [x] カメラ起動→OCRテキスト抽出（ReceiptScannerScreen + MockReceiptOcrService）
- [x] 金額・店名の自動抽出（ReceiptAmountExtractor: 正規表現ベース）
- [x] 喜捨ログに画像添付（TrialQuest.receiptImagePath / OfferingResult.receiptImagePath）
- [x] OfferingInputScreenにレシート撮影ボタン統合
- [x] 試験: 20件追加（全85試験通過）

### 🟡 拡張3: 餓鬼ゾーン ✅（皐月十六日 夜刻——イシコリ）
- [x] SATORI低下時の段階警告（GakiZoneWarningBanner: 守護神名+絵文字の警告バナー）
- [x] 餓鬼ゾーン専用UI（GakiZoneOverlay: モノクロフィルター + ヴィネット視界狭窄演出）
- [x] MainScreen統合（body全体のモノクロ化 + HPバー前に警告バナー表示）
- [x] 試験: 9件追加（全94試験通過）

### 🟢 拡張4: 裏面（空） ✅（皐月十七日 朝刻——イシコリ）
- [x] SATORI MAX到達時のHPバーフェードアウト（AnimatedOpacityでopacity: 0.3に）
- [x] 縁起曼荼羅（支出の連鎖を光の線で可視化、黄金比螺旋配置 + アニメーション粒子）
- [x] 表⇄裏の切り替え（FAB切替 + 空の世界ラベル + 夜空AppBar）
- [x] 試験: 10件追加（全104試験通過）

### ✅ 拡張5: アプリ間連携（皐月二十二日 朝——イシコリ確認・完了）
- [x] rpg-taskのデイリークエストにKozuchi試練が出現（rpg-task: KozuchiQuestCard + KozuchiQuestService、Kozuchi: KozuchiQuestExporter + MainScreen統合）
- [x] tsundoku-questの蔵書追加で弁財天ボーナス（tsundoku: TsundokuBookEventExporter + book_data_provider配線、Kozuchi: BenzaitenBookBonusService + MainScreen配線）
- コミット: rpg-task `039ca52` / Kozuchi `bcd174a` / tsundoku `4a43a61`

---

**次回自律サイクル**: 全拡張完了。次は試験強化・開顕準備（要：創造主様のPlay Console操作）。tsundoku-questのPlay Console開顕が完了し次第、蔵書追加イベントの共有ストレージ連携を実装する。

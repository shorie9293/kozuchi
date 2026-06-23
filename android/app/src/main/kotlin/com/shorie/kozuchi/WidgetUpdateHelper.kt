package com.shorie.kozuchi

import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ウィジェット更新ヘルパー — kozuchi Android ホームウィジェット用。
 *
 * Flutter アプリが shared_preferences プラグイン経由で保存した
 * プレイヤー状態（HP/EXP）とデイリークエスト（本日の試練）を読み取り、
 * RemoteViews に整形して返す。副作用なし。純粋な data → RemoteViews マッピング。
 *
 * ## 使用例
 * ```kotlin
 * val helper = WidgetUpdateHelper.create(context)
 * val remoteViews = helper.build(
 *     layoutId = R.layout.widget_layout,
 *     balanceTextId = R.id.widget_balance,
 *     trialsTextId = R.id.widget_trials,
 *     hpBarId = R.id.widget_hp_bar,
 *     expTextId = R.id.widget_exp,
 *     packageName = context.packageName,
 * )
 * appWidgetManager.updateAppWidget(appWidgetId, remoteViews)
 * ```
 *
 * ## エラーハンドリング
 * - SharedPreferences 未初期化（アプリ未起動） → デフォルト値表示
 * - JSON 破損 → デフォルト値表示
 * - 日付跨ぎ → 試練カウントをリセット
 */
class WidgetUpdateHelper private constructor(
    private val prefs: SharedPreferences,
) {
    // ───── 公開 API ─────

    /**
     * ウィジェットデータを読み取り、整形済み RemoteViews を構築して返す。
     *
     * @param layoutId   ウィジェットレイアウトのリソース ID（R.layout.widget_layout 等）
     * @param balanceTextId  残高表示用 TextView の ID
     * @param trialsTextId   本日の試練表示用 TextView の ID
     * @param hpBarId        HP バー用 ProgressBar の ID
     * @param expTextId      EXP 表示用 TextView の ID
     * @param packageName    アプリのパッケージ名（context.packageName）
     * @return 設定済み RemoteViews（そのまま updateAppWidget() に渡せる）
     */
    fun build(
        layoutId: Int,
        balanceTextId: Int,
        trialsTextId: Int,
        hpBarId: Int,
        expTextId: Int,
        packageName: String,
    ): RemoteViews {
        val data = fetchWidgetData()
        val views = RemoteViews(packageName, layoutId)

        // 残高テキスト（¥1,234,567 形式）
        views.setTextViewText(balanceTextId, formatCurrency(data.balance))
        views.setContentDescription(balanceTextId, "残高 ${formatCurrency(data.balance)}")

        // 本日の試練（"試練 2/3" 形式）
        views.setTextViewText(trialsTextId, formatTrials(data.trialsCompleted, data.trialsTotal))
        views.setContentDescription(
            trialsTextId,
            "本日の試練 ${data.trialsCompleted}/${data.trialsTotal}",
        )

        // HP バー（ProgressBar）
        views.setProgressBar(hpBarId, data.hpBarMax, data.hpBarProgress, false)
        views.setContentDescription(
            hpBarId,
            "HP ${data.hpBarProgress}/${data.hpBarMax}",
        )

        // EXP テキスト
        views.setTextViewText(expTextId, "EXP ${data.exp}")
        views.setContentDescription(expTextId, "経験値 ${data.exp}")

        return views
    }

    // ───── データ取得 ─────

    /**
     * SharedPreferences からウィジェットデータを読み取る。
     *
     * 破損データ・未初期化時はデフォルト値にフォールバックする。
     */
    fun fetchWidgetData(): WidgetData {
        return try {
            val playerJson = prefs.getString(KEY_PLAYER_STATE, null)
            val questsJson = prefs.getString(KEY_DAILY_QUESTS, null)

            val (balance, exp) = parsePlayerState(playerJson)
            val (completed, total) = parseDailyQuests(questsJson)

            // HP バーの最大値：残高が初期値より大きければそれに合わせる
            val hpBarMax = maxOf(HP_BAR_MAX, balance)

            WidgetData(
                balance = balance,
                exp = exp,
                trialsCompleted = completed,
                trialsTotal = total,
                hpBarProgress = balance,
                hpBarMax = hpBarMax,
            )
        } catch (e: Exception) {
            fallbackData()
        }
    }

    // ───── JSON パース ─────

    private fun parsePlayerState(json: String?): Pair<Int, Int> {
        if (json.isNullOrBlank()) return Pair(DEFAULT_HP, DEFAULT_EXP)
        return try {
            val obj = JSONObject(json)
            val hp = obj.optInt("hp", DEFAULT_HP)
            val exp = obj.optInt("exp", DEFAULT_EXP)
            Pair(hp, exp)
        } catch (e: Exception) {
            Pair(DEFAULT_HP, DEFAULT_EXP)
        }
    }

    private fun parseDailyQuests(json: String?): Pair<Int, Int> {
        if (json.isNullOrBlank()) return Pair(0, 0)
        return try {
            val obj = JSONObject(json)
            val dateStr = obj.optString("date", "")

            // 日付跨ぎ：本日以外のデータは試練未割当とみなす
            if (!isToday(dateStr)) {
                return Pair(0, 0)
            }

            val questsArray = obj.optJSONArray("quests") ?: return Pair(0, 0)
            var total = 0
            var completed = 0
            for (i in 0 until questsArray.length()) {
                val quest = questsArray.optJSONObject(i) ?: continue
                total++
                if (quest.optBoolean("isCompleted", false)) {
                    completed++
                }
            }
            Pair(completed, total)
        } catch (e: Exception) {
            Pair(0, 0)
        }
    }

    /**
     * 日付文字列（ISO 8601 日付部またはフルタイムスタンプ）が本日か判定。
     */
    private fun isToday(dateStr: String): Boolean {
        if (dateStr.isBlank()) return false
        return try {
            val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val today = fmt.format(Date())
            // ISO 8601 の日付部のみ比較（"2026-06-23T12:34:56" → "2026-06-23"）
            val datePart = dateStr.substringBefore('T')
            datePart == today
        } catch (e: Exception) {
            false
        }
    }

    // ───── フォーマット ─────

    /**
     * 金額を日本円表記に整形（¥1,234,567）
     */
    private fun formatCurrency(amount: Int): String {
        return try {
            val fmt = NumberFormat.getNumberInstance(Locale.JAPAN)
            "¥${fmt.format(amount)}"
        } catch (e: Exception) {
            "¥$amount"
        }
    }

    /**
     * 試練進捗を表示用文字列に整形
     */
    private fun formatTrials(completed: Int, total: Int): String {
        return if (total > 0) {
            "試練 $completed/$total"
        } else {
            "試練 -"
        }
    }

    // ───── フォールバック ─────

    private fun fallbackData() = WidgetData(
        balance = DEFAULT_HP,
        exp = DEFAULT_EXP,
        trialsCompleted = 0,
        trialsTotal = 0,
        hpBarProgress = DEFAULT_HP,
        hpBarMax = HP_BAR_MAX,
    )

    // ───── データクラス ─────

    /**
     * ウィジェット表示用データ。
     *
     * @param balance          現在の残高（HP）
     * @param exp              現在の経験値（EXP）
     * @param trialsCompleted  本日達成済みの試練数
     * @param trialsTotal      本日の全試練数
     * @param hpBarProgress    HP バーの現在値
     * @param hpBarMax         HP バーの最大値
     */
    data class WidgetData(
        val balance: Int,
        val exp: Int,
        val trialsCompleted: Int,
        val trialsTotal: Int,
        val hpBarProgress: Int,
        val hpBarMax: Int,
    )

    // ───── コンパニオン（ファクトリ） ─────

    companion object {
        // Flutter shared_preferences プラグインの保存先
        private const val PREFS_NAME = "FlutterSharedPreferences"

        // Flutter アプリ側 PlayerRepository / DailyQuestRepository と一致するキー
        private const val KEY_PLAYER_STATE = "kozuchi_player_state"
        private const val KEY_DAILY_QUESTS = "kozuchi_daily_quests_state"

        // デフォルト値（PlayerModel.defaultPlayer() と一致）
        private const val DEFAULT_HP = 100000
        private const val DEFAULT_EXP = 0

        // HP バー基準最大値
        private const val HP_BAR_MAX = 100000

        /**
         * WidgetUpdateHelper のインスタンスを生成する。
         *
         * Flutter アプリの SharedPreferences からデータを読み取るよう設定される。
         *
         * @param context Android コンテキスト
         */
        fun create(context: Context): WidgetUpdateHelper {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return WidgetUpdateHelper(prefs)
        }
    }
}

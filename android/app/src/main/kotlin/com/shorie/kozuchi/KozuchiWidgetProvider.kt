package com.shorie.kozuchi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews

/**
 * kozuchi ホームウィジェットの AppWidgetProvider。
 *
 * ## 責務
 * - onUpdate(): 全ウィジェットインスタンスのデータを更新して描画
 * - onAppWidgetOptionsChanged(): リサイズ時にレイアウトを再適用
 * - onDeleted(): ウィジェット削除時の後始末
 * - タップ → MainActivity 起動 (PendingIntent)
 *
 * ## データフロー
 * WidgetUpdateHelper（Task 0 成果物）→ RemoteViews → AppWidgetManager.updateAppWidget()
 *
 * ## 更新サイクル
 * 本クラスは手動更新のみ（updatePeriodMillis=0）。
 * 定期更新は WorkManager（Task 2）が担当する。
 */
class KozuchiWidgetProvider : AppWidgetProvider() {

    override fun onEnabled(context: Context) {
        // 最初のウィジェットが配置されたら定期更新を開始
        WidgetWorkScheduler.schedulePeriodicUpdate(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateSingleWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        // ウィジェットのリサイズ時に再描画
        updateSingleWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        // ウィジェット削除時に固有リソースがあれば解放。
        // 現時点では SharedPreferences 共有のため特段の後始末は不要。
    }

    override fun onDisabled(context: Context) {
        // 最後のウィジェットが削除されたら定期更新を停止
        WidgetWorkScheduler.cancelPeriodicUpdate(context)
    }

    // ───── 内部実装 ─────

    /**
     * 単一ウィジェットインスタンスの RemoteViews を構築・適用する。
     *
     * WidgetUpdateHelper にデータ取得とビュー設定を委譲し、
     * タップ PendingIntent を付与してから AppWidgetManager に渡す。
     */
    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val helper = WidgetUpdateHelper.create(context)
        val views = helper.build(
            layoutId = R.layout.widget_layout,
            balanceTextId = R.id.widget_balance,
            trialsTextId = R.id.widget_trials,
            hpBarId = R.id.widget_hp_bar,
            expTextId = R.id.widget_exp,
            packageName = context.packageName,
        )

        // タップで MainActivity を起動する PendingIntent をルートビューに設定
        val tapIntent = buildLaunchIntent(context, appWidgetId)
        views.setOnClickPendingIntent(R.id.widget_root, tapIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /**
     * ウィジェットタップ時にアプリの MainActivity を起動する PendingIntent を構築。
     *
     * FLAG_IMMUTABLE により PendingIntent の不変性を保証（Android 12+ 必須）。
     * UI要素ごとに異なる intent extras が必要な場合は appWidgetId を付与する。
     */
    private fun buildLaunchIntent(context: Context, appWidgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(
            context,
            appWidgetId, // 一意なrequestCode = appWidgetId
            intent,
            flags,
        )
    }
}

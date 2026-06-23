package com.shorie.kozuchi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * ウィジェット定期更新 Worker — WorkManager から 15 分間隔で呼ばれる。
 *
 * ## 役割
 * 1. AppWidgetManager から本アプリの全ウィジェットインスタンス ID を取得
 * 2. 各インスタンスに対して WidgetUpdateHelper で最新データを取得 → RemoteViews 構築
 * 3. updateAppWidget() で反映
 *
 * ## ワーカー内で許される操作
 * - AppWidgetManager#updateAppWidget() — API 26+ でもバックグラウンド実行制限の対象外
 * - SharedPreferences 読み取り（WidgetUpdateHelper 経由）
 * - RemoteViews 構築（UI スレッド不要）
 *
 * ## エラーハンドリング
 * - 例外発生時は Result.retry() を返す → WorkManager がバックオフ付きで再試行
 * - ウィジェット未配置時（appWidgetIds が空）は Result.success() で正常終了（no-op）
 */
class WidgetUpdateWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "WidgetUpdateWorker"
    }

    override suspend fun doWork(): Result {
        return try {
            val appContext = applicationContext
            val appWidgetManager = AppWidgetManager.getInstance(appContext)

            // 対象のウィジェットプロバイダー ComponentName
            // ※ AppWidgetProvider が未作成でも ComponentName は解決可能（文字列指定）
            val componentName = ComponentName(
                appContext.packageName,
                "com.shorie.kozuchi.KozuchiWidgetProvider",
            )

            // 配置済みウィジェットの ID 一覧を取得
            val appWidgetIds: IntArray = appWidgetManager.getAppWidgetIds(componentName)

            if (appWidgetIds.isEmpty()) {
                // ウィジェット未配置 → 正常終了（no-op）
                Log.d(TAG, "ウィジェット未配置のためスキップ")
                return Result.success()
            }

            // WidgetUpdateHelper で最新データ取得 → RemoteViews 構築
            val helper = WidgetUpdateHelper.create(appContext)
            val layoutId = R.layout.widget_layout
            val packageName = appContext.packageName

            // タップで MainActivity を起動する PendingIntent（全ウィジェット共通）
            val tapIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

            for (appWidgetId in appWidgetIds) {
                val views = helper.build(
                    layoutId = layoutId,
                    balanceTextId = R.id.widget_balance,
                    trialsTextId = R.id.widget_trials,
                    hpBarId = R.id.widget_hp_bar,
                    expTextId = R.id.widget_exp,
                    packageName = packageName,
                )

                // タップ PendingIntent を付与（KozuchiWidgetProvider と一致）
                val tapIntent = Intent(appContext, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val pendingIntent = PendingIntent.getActivity(
                    appContext,
                    appWidgetId,
                    tapIntent,
                    tapIntentFlags,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            }

            Log.d(TAG, "${appWidgetIds.size} ウィジェットを更新しました")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "ウィジェット更新に失敗", e)
            Result.retry()
        }
    }
}

package com.shorie.kozuchi

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * WorkManager によるウィジェット定期更新のスケジューラ。
 *
 * ## 使用法
 * 以下のいずれかで呼び出す（推奨: AppWidgetProvider#onEnabled）：
 *
 * ### 方法 A: AppWidgetProvider#onEnabled（推奨）
 * ```kotlin
 * override fun onEnabled(context: Context) {
 *     WidgetWorkScheduler.schedulePeriodicUpdate(context)
 * }
 * ```
 * → ウィジェットがホーム画面に配置された時のみスケジュール → 省リソース
 *
 * ### 方法 B: Application#onCreate（フォールバック）
 * ```kotlin
 * override fun onCreate() {
 *     super.onCreate()
 *     WidgetWorkScheduler.schedulePeriodicUpdate(this)
 * }
 * ```
 * → アプリ起動時に常にスケジュール → 確実だがリソース消費増
 *
 * ## 挙動
 * - 15 分間隔で WidgetUpdateWorker を実行
 * - ExistingPeriodicWorkPolicy.KEEP → 既存の定期ワークがあれば上書きしない
 * - バッテリー制約なし（最小限の制約で常時動作）
 */
object WidgetWorkScheduler {

    private const val TAG = "WidgetWorkScheduler"
    private const val UNIQUE_WORK_NAME = "kozuchi_widget_periodic_update"
    private const val UPDATE_INTERVAL_MINUTES = 15L

    /**
     * ウィジェット定期更新をスケジュールする。
     * 既にスケジュール済みの場合は上書きしない（KEEP ポリシー）。
     *
     * @param context アプリケーションコンテキスト
     */
    fun schedulePeriodicUpdate(context: Context) {
        try {
            // 最小限の制約（バッテリー低下時も動作可）
            val constraints = Constraints.Builder()
                .setRequiresBatteryNotLow(false)
                .build()

            val periodicWorkRequest = PeriodicWorkRequestBuilder<WidgetUpdateWorker>(
                UPDATE_INTERVAL_MINUTES, TimeUnit.MINUTES,
            )
                .setConstraints(constraints)
                .addTag("kozuchi_widget")
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                periodicWorkRequest,
            )

            Log.i(TAG, "定期更新をスケジュールしました（${UPDATE_INTERVAL_MINUTES}分間隔）")
        } catch (e: Exception) {
            Log.e(TAG, "定期更新のスケジュールに失敗", e)
        }
    }

    /**
     * 定期更新のスケジュールを解除する。
     * AppWidgetProvider#onDisabled() から呼び出すことを想定。
     *
     * @param context アプリケーションコンテキスト
     */
    fun cancelPeriodicUpdate(context: Context) {
        try {
            WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
            Log.i(TAG, "定期更新を解除しました")
        } catch (e: Exception) {
            Log.e(TAG, "定期更新の解除に失敗", e)
        }
    }
}

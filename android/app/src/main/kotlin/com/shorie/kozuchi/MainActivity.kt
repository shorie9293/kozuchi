package com.shorie.kozuchi

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // WorkManager によるウィジェット定期更新をスケジュール
        // ※ 本来は KozuchiWidgetProvider#onEnabled() でスケジュールするのが望ましいが、
        //    AppWidgetProvider 未作成時はここでフォールバック起動する。
        WidgetWorkScheduler.schedulePeriodicUpdate(applicationContext)
    }
}

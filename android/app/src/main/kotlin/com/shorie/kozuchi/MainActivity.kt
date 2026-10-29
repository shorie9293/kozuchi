package com.shorie.kozuchi

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // WorkManager によるウィジェット定期更新をスケジュール
        // ※ 本来は KozuchiWidgetProvider#onEnabled() でスケジュールするのが望ましいが、
        //    AppWidgetProvider 未作成時はここでフォールバック起動する。
        WidgetWorkScheduler.schedulePeriodicUpdate(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 通知権限の拒否バナーから OS のアプリ設定画面を開くためのチャネル。
        // Android のアプリ詳細設定は URL スキームで開けないためネイティブ実装を持つ。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.shorie.kozuchi/app_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openAppSettings") {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.fromParts("package", packageName, null)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}

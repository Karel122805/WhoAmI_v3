package com.example.whoami_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "whoami/reminder_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: "Recordatorio"
                        val timeMillis = call.argument<Long>("timeMillis") ?: 0L

                        AlarmScheduler.scheduleAlarm(
                            context = this,
                            id = id,
                            title = title,
                            timeMillis = timeMillis
                        )

                        result.success(true)
                    }

                    "cancelAlarm" -> {
                        val id = call.argument<Int>("id") ?: 0
                        AlarmScheduler.cancelAlarm(this, id)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
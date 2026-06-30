package com.example.whoami_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "whoami/reminder_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scheduleAlarm" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title =
                            call.argument<String>("title") ?: "Recordatorio"
                        val description =
                            call.argument<String>("description") ?: ""
                        val timeMillis =
                            call.argument<Long>("timeMillis") ?: 0L

                        if (id == 0 || timeMillis <= 0L) {
                            result.error(
                                "invalid_alarm",
                                "El identificador o la fecha de la alarma no son válidos.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        AlarmScheduler.scheduleAlarm(
                            context = this,
                            id = id,
                            title = title,
                            description = description,
                            timeMillis = timeMillis
                        )

                        result.success(true)
                    }

                    "cancelAlarm" -> {
                        val id = call.argument<Int>("id") ?: 0

                        if (id == 0) {
                            result.error(
                                "invalid_alarm",
                                "El identificador de la alarma no es válido.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        AlarmScheduler.cancelAlarm(this, id)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            } catch (exception: Exception) {
                result.error(
                    "alarm_error",
                    exception.message ?: "No se pudo procesar la alarma.",
                    null
                )
            }
        }
    }
}

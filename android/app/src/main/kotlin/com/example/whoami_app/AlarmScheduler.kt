package com.example.whoami_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

object AlarmScheduler {

    private const val PREFS_NAME = "whoami_native_alarms"
    private const val KEY_PREFIX = "alarm_"

    data class StoredAlarm(
        val id: Int,
        val title: String,
        val description: String,
        val timeMillis: Long
    )

    fun scheduleAlarm(
        context: Context,
        id: Int,
        title: String,
        timeMillis: Long,
        description: String = ""
    ) {
        require(id != 0) {
            "El identificador de la alarma no puede ser 0."
        }

        require(timeMillis > 0L) {
            "La fecha de la alarma no es válida."
        }

        scheduleAlarmInternal(
            context = context,
            alarm = StoredAlarm(
                id = id,
                title = title.ifBlank { "Recordatorio" },
                description = description,
                timeMillis = timeMillis
            ),
            persist = true
        )
    }

    private fun scheduleAlarmInternal(
        context: Context,
        alarm: StoredAlarm,
        persist: Boolean
    ) {
        val appContext = context.applicationContext

        if (persist) {
            saveAlarm(appContext, alarm)
        }

        val alarmManager =
            appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val receiverIntent = Intent(
            appContext,
            AlarmReceiver::class.java
        ).apply {
            action = alarmAction(alarm.id)

            putExtra("id", alarm.id)
            putExtra("reminderId", alarm.id)
            putExtra("alarmId", alarm.id)
            putExtra("title", alarm.title)
            putExtra("description", alarm.description)
            putExtra("scheduledTime", alarm.timeMillis)
        }

        val alarmPendingIntent = PendingIntent.getBroadcast(
            appContext,
            alarm.id,
            receiverIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
        )

        val activityIntent = Intent(
            appContext,
            AlarmActivity::class.java
        ).apply {
            flags =
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP

            putExtra("id", alarm.id)
            putExtra("reminderId", alarm.id)
            putExtra("alarmId", alarm.id)
            putExtra("title", alarm.title)
            putExtra("description", alarm.description)
            putExtra("scheduledTime", alarm.timeMillis)
        }

        val showPendingIntent = PendingIntent.getActivity(
            appContext,
            alarm.id,
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms()
            ) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    alarm.timeMillis,
                    alarmPendingIntent
                )
                return
            }

            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(
                    alarm.timeMillis,
                    showPendingIntent
                ),
                alarmPendingIntent
            )
        } catch (securityException: SecurityException) {
            securityException.printStackTrace()

            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                alarm.timeMillis,
                alarmPendingIntent
            )
        } catch (exception: Exception) {
            exception.printStackTrace()
            throw exception
        }
    }

    fun cancelAlarm(
        context: Context,
        id: Int
    ) {
        val appContext = context.applicationContext

        val intent = Intent(
            appContext,
            AlarmReceiver::class.java
        ).apply {
            action = alarmAction(id)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            appContext,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or
                PendingIntent.FLAG_IMMUTABLE
        )

        if (pendingIntent != null) {
            val alarmManager =
                appContext.getSystemService(Context.ALARM_SERVICE)
                    as AlarmManager

            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }

        removeStoredAlarm(appContext, id)
    }

    fun markDelivered(
        context: Context,
        id: Int
    ) {
        removeStoredAlarm(
            context.applicationContext,
            id
        )
    }

    fun restoreSavedAlarms(
        context: Context
    ) {
        val appContext = context.applicationContext
        val alarms = loadStoredAlarms(appContext)

        if (alarms.isEmpty()) {
            return
        }

        val now = System.currentTimeMillis()

        for (alarm in alarms) {
            try {
                /*
                 * Si venció mientras el teléfono estaba apagado, se muestra
                 * pocos segundos después del arranque.
                 */
                val restoredTime =
                    if (alarm.timeMillis <= now) {
                        now + 5_000L
                    } else {
                        alarm.timeMillis
                    }

                scheduleAlarmInternal(
                    context = appContext,
                    alarm = alarm.copy(
                        timeMillis = restoredTime
                    ),
                    persist = true
                )
            } catch (exception: Exception) {
                exception.printStackTrace()
            }
        }
    }

    private fun saveAlarm(
        context: Context,
        alarm: StoredAlarm
    ) {
        val json = JSONObject().apply {
            put("id", alarm.id)
            put("title", alarm.title)
            put("description", alarm.description)
            put("timeMillis", alarm.timeMillis)
        }

        preferences(context)
            .edit()
            .putString(
                "$KEY_PREFIX${alarm.id}",
                json.toString()
            )
            .apply()
    }

    private fun loadStoredAlarms(
        context: Context
    ): List<StoredAlarm> {
        val prefs = preferences(context)
        val alarms = mutableListOf<StoredAlarm>()

        for ((key, value) in prefs.all) {
            if (!key.startsWith(KEY_PREFIX)) {
                continue
            }

            val raw = value as? String ?: continue

            try {
                val json = JSONObject(raw)

                val id = json.optInt("id", 0)
                val timeMillis =
                    json.optLong("timeMillis", 0L)

                if (id == 0 || timeMillis <= 0L) {
                    prefs.edit().remove(key).apply()
                    continue
                }

                alarms.add(
                    StoredAlarm(
                        id = id,
                        title = json.optString(
                            "title",
                            "Recordatorio"
                        ),
                        description = json.optString(
                            "description",
                            ""
                        ),
                        timeMillis = timeMillis
                    )
                )
            } catch (exception: Exception) {
                exception.printStackTrace()
                prefs.edit().remove(key).apply()
            }
        }

        return alarms
    }

    private fun removeStoredAlarm(
        context: Context,
        id: Int
    ) {
        preferences(context)
            .edit()
            .remove("$KEY_PREFIX$id")
            .apply()
    }

    private fun preferences(
        context: Context
    ) = context.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE
    )

    private fun alarmAction(
        id: Int
    ): String {
        return "com.example.whoami_app.ALARM_$id"
    }
}

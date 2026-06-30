package com.example.whoami_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(
        context: Context,
        intent: Intent
    ) {
        val alarmId = readAlarmId(intent)

        val title =
            intent.getStringExtra("title")
                ?: intent.getStringExtra("alarmTitle")
                ?: "Recordatorio"

        val description =
            intent.getStringExtra("description")
                ?: intent.getStringExtra("body")
                ?: ""

        /*
         * Evita que una alarma ya entregada vuelva a restaurarse
         * después de reiniciar el teléfono.
         */
        AlarmScheduler.markDelivered(
            context,
            alarmId
        )

        wakeScreen(context)
        createAlarmChannel(context)

        val alarmActivityIntent =
            Intent(
                context,
                AlarmActivity::class.java
            ).apply {
                flags =
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP

                putExtra("id", alarmId)
                putExtra("reminderId", alarmId)
                putExtra("alarmId", alarmId)
                putExtra("title", title)
                putExtra("description", description)
                putExtra(
                    "isSnoozed",
                    intent.getBooleanExtra(
                        "isSnoozed",
                        false
                    )
                )
                putExtra(
                    "scheduledTime",
                    intent.getLongExtra(
                        "scheduledTime",
                        0L
                    )
                )
            }

        val activityPendingIntent =
            PendingIntent.getActivity(
                context,
                alarmId,
                alarmActivityIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE
            )

        val notification =
            NotificationCompat.Builder(
                context,
                CHANNEL_ID
            )
                .setSmallIcon(
                    android.R.drawable.ic_lock_idle_alarm
                )
                .setContentTitle(
                    "Alarma de recordatorio"
                )
                .setContentText(title)
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText(
                            if (description.isBlank()) {
                                title
                            } else {
                                "$title\n$description"
                            }
                        )
                )
                .setPriority(
                    NotificationCompat.PRIORITY_MAX
                )
                .setCategory(
                    NotificationCompat.CATEGORY_ALARM
                )
                .setVisibility(
                    NotificationCompat.VISIBILITY_PUBLIC
                )
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setFullScreenIntent(
                    activityPendingIntent,
                    true
                )
                .setContentIntent(
                    activityPendingIntent
                )
                .build()

        try {
            NotificationManagerCompat
                .from(context)
                .notify(
                    alarmId,
                    notification
                )
        } catch (exception: SecurityException) {
            exception.printStackTrace()
        }
    }

    private fun readAlarmId(
        intent: Intent
    ): Int {
        val receivedId = when {
            intent.hasExtra("id") ->
                intent.getIntExtra("id", 0)

            intent.hasExtra("reminderId") ->
                intent.getIntExtra(
                    "reminderId",
                    0
                )

            intent.hasExtra("alarmId") ->
                intent.getIntExtra(
                    "alarmId",
                    0
                )

            else -> 0
        }

        return if (receivedId != 0) {
            receivedId
        } else {
            (System.currentTimeMillis() %
                Int.MAX_VALUE).toInt()
        }
    }

    private fun wakeScreen(
        context: Context
    ) {
        try {
            val powerManager =
                context.getSystemService(
                    Context.POWER_SERVICE
                ) as PowerManager

            @Suppress("DEPRECATION")
            val wakeLock =
                powerManager.newWakeLock(
                    PowerManager.FULL_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                    "whoami:reminder_alarm_wakelock"
                )

            wakeLock.acquire(10_000L)
        } catch (exception: Exception) {
            exception.printStackTrace()
        }
    }

    private fun createAlarmChannel(
        context: Context
    ) {
        if (
            Build.VERSION.SDK_INT <
            Build.VERSION_CODES.O
        ) {
            return
        }

        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Alarmas de recordatorios",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description =
                    "Alarmas importantes de WhoAmI?"
                enableLights(true)
                lightColor = Color.RED
                enableVibration(false)
                setSound(null, null)
                setBypassDnd(true)
                lockscreenVisibility =
                    Notification.VISIBILITY_PUBLIC
            }

        val notificationManager =
            context.getSystemService(
                NotificationManager::class.java
            )

        notificationManager.createNotificationChannel(
            channel
        )
    }

    companion object {
        private const val CHANNEL_ID =
            "whoami_reminder_alarm_channel"
    }
}

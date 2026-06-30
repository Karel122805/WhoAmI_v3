package com.example.whoami_app

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationManagerCompat

class AlarmActivity : Activity() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    private var alarmId: Int = 0
    private var alarmTitle: String = "Recordatorio"
    private var alarmDescription: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        showOverLockScreen()
        readAlarmData(intent)

        startSound()
        startVibration()
        createView()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)

        if (intent == null) {
            return
        }

        setIntent(intent)

        stopAlarm()
        readAlarmData(intent)

        startSound()
        startVibration()
        createView()
    }

    private fun showOverLockScreen() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

    private fun readAlarmData(intent: Intent) {
        alarmId = when {
            intent.hasExtra("id") -> {
                intent.getIntExtra("id", 0)
            }

            intent.hasExtra("reminderId") -> {
                intent.getIntExtra("reminderId", 0)
            }

            intent.hasExtra("alarmId") -> {
                intent.getIntExtra("alarmId", 0)
            }

            else -> {
                0
            }
        }

        alarmTitle =
            intent.getStringExtra("title")
                ?: intent.getStringExtra("alarmTitle")
                ?: "Recordatorio"

        alarmDescription =
            intent.getStringExtra("description")
                ?: intent.getStringExtra("body")
                ?: ""
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun background(
        color: Int,
        radius: Int,
        strokeColor: Int? = null
    ): GradientDrawable {
        return GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(radius).toFloat()

            if (strokeColor != null) {
                setStroke(dp(1), strokeColor)
            }
        }
    }

    private fun createView() {
        val scrollView = ScrollView(this).apply {
            isFillViewport = true

            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(
                    Color.rgb(246, 248, 255),
                    Color.rgb(232, 242, 255)
                )
            )
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER

            setPadding(
                dp(20),
                dp(28),
                dp(20),
                dp(28)
            )
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER

            setPadding(
                dp(24),
                dp(28),
                dp(24),
                dp(28)
            )

            background = background(
                color = Color.WHITE,
                radius = 28,
                strokeColor = Color.rgb(226, 233, 246)
            )

            elevation = dp(8).toFloat()
        }

        val screenWidth = resources.displayMetrics.widthPixels

        val cardWidth = minOf(
            screenWidth - dp(40),
            dp(430)
        )

        val cardParams = LinearLayout.LayoutParams(
            cardWidth,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )

        val icon = TextView(this).apply {
            text = "⏰"
            textSize = 34f
            gravity = Gravity.CENTER

            background = background(
                color = Color.rgb(196, 153, 238),
                radius = 999
            )
        }

        icon.layoutParams = LinearLayout.LayoutParams(
            dp(86),
            dp(86)
        ).apply {
            bottomMargin = dp(18)
        }

        val appTitle = TextView(this).apply {
            text = "WhoAmI?"
            textSize = 32f

            setTextColor(
                Color.rgb(7, 19, 31)
            )

            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            includeFontPadding = false
        }

        val subtitle = TextView(this).apply {
            text = "Alarma de recordatorio"
            textSize = 18f

            setTextColor(
                Color.rgb(113, 121, 138)
            )

            gravity = Gravity.CENTER

            setPadding(
                0,
                dp(12),
                0,
                dp(20)
            )
        }

        val reminderText = TextView(this).apply {
            text = alarmTitle
            textSize = 24f

            setTextColor(
                Color.rgb(25, 30, 40)
            )

            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            maxLines = 3

            setPadding(
                0,
                0,
                0,
                if (alarmDescription.isBlank()) {
                    dp(26)
                } else {
                    dp(10)
                }
            )
        }

        val descriptionText = TextView(this).apply {
            text = alarmDescription
            textSize = 17f

            setTextColor(
                Color.rgb(90, 98, 113)
            )

            gravity = Gravity.CENTER
            maxLines = 4

            visibility =
                if (alarmDescription.isBlank()) {
                    TextView.GONE
                } else {
                    TextView.VISIBLE
                }

            setPadding(
                0,
                0,
                0,
                dp(26)
            )
        }

        val snoozeButton = TextView(this).apply {
            text = "Posponer 5 min"
            textSize = 17f

            setTextColor(
                Color.rgb(7, 19, 31)
            )

            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER

            background = background(
                color = Color.rgb(232, 240, 255),
                radius = 18
            )

            isClickable = true
            isFocusable = true

            setOnClickListener {
                snoozeAlarm()
            }
        }

        snoozeButton.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(56)
        ).apply {
            bottomMargin = dp(12)
        }

        val stopButton = TextView(this).apply {
            text = "Detener alarma"
            textSize = 17f
            setTextColor(Color.WHITE)

            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER

            background = background(
                color = Color.rgb(144, 202, 249),
                radius = 18
            )

            isClickable = true
            isFocusable = true

            setOnClickListener {
                cancelAlarmNotification()
                stopAlarm()
                finishAndRemoveTask()
            }
        }

        stopButton.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(56)
        )

        card.addView(icon)
        card.addView(appTitle)
        card.addView(subtitle)
        card.addView(reminderText)
        card.addView(descriptionText)
        card.addView(snoozeButton)
        card.addView(stopButton)

        root.addView(card, cardParams)
        scrollView.addView(root)

        setContentView(scrollView)
    }

    private fun snoozeAlarm() {
        /*
         * Primero se elimina la notificación actual y se detienen
         * el sonido y la vibración.
         */
        cancelAlarmNotification()
        stopAlarm()

        val validAlarmId =
            if (alarmId != 0) {
                alarmId
            } else {
                (
                    System.currentTimeMillis() %
                        Int.MAX_VALUE
                    ).toInt()
            }

        val triggerTime =
            System.currentTimeMillis() +
                (5L * 60L * 1000L)

        val receiverIntent = Intent(
            this,
            AlarmReceiver::class.java
        ).apply {
            action =
                "com.example.whoami_app.SNOOZED_ALARM_$validAlarmId"

            putExtra("id", validAlarmId)
            putExtra("reminderId", validAlarmId)
            putExtra("alarmId", validAlarmId)

            putExtra("title", alarmTitle)
            putExtra("description", alarmDescription)

            putExtra("isSnoozed", true)
            putExtra("scheduledTime", triggerTime)
        }

        /*
         * El PendingIntent de posponer utiliza un requestCode
         * distinto del PendingIntent original.
         */
        val snoozeRequestCode =
            if (validAlarmId <= Int.MAX_VALUE - 500000) {
                validAlarmId + 500000
            } else {
                validAlarmId
            }

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            snoozeRequestCode,
            receiverIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager =
            getSystemService(
                Context.ALARM_SERVICE
            ) as AlarmManager

        try {
            if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms()
            ) {
                /*
                 * Respaldo cuando no está concedido el permiso
                 * de alarmas exactas.
                 */
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }

            Toast.makeText(
                this,
                "Alarma pospuesta 5 minutos",
                Toast.LENGTH_SHORT
            ).show()

            finishAndRemoveTask()
        } catch (exception: SecurityException) {
            exception.printStackTrace()

            try {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )

                Toast.makeText(
                    this,
                    "Alarma pospuesta 5 minutos",
                    Toast.LENGTH_SHORT
                ).show()

                finishAndRemoveTask()
            } catch (fallbackException: Exception) {
                fallbackException.printStackTrace()

                Toast.makeText(
                    this,
                    "No se pudo posponer la alarma",
                    Toast.LENGTH_LONG
                ).show()
            }
        } catch (exception: Exception) {
            exception.printStackTrace()

            Toast.makeText(
                this,
                "No se pudo posponer la alarma",
                Toast.LENGTH_LONG
            ).show()
        }
    }

    private fun cancelAlarmNotification() {
        try {
            /*
             * AlarmReceiver crea la notificación utilizando alarmId,
             * por lo que debe cancelarse con el mismo ID.
             */
            NotificationManagerCompat
                .from(this)
                .cancel(alarmId)
        } catch (exception: Exception) {
            exception.printStackTrace()
        }
    }

    private fun startSound() {
        stopMediaPlayer()

        try {
            val alarmUri =
                RingtoneManager.getDefaultUri(
                    RingtoneManager.TYPE_ALARM
                )
                    ?: RingtoneManager.getDefaultUri(
                        RingtoneManager.TYPE_NOTIFICATION
                    )

            mediaPlayer = MediaPlayer().apply {
                setDataSource(
                    this@AlarmActivity,
                    alarmUri
                )

                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(
                            AudioAttributes.USAGE_ALARM
                        )
                        .setContentType(
                            AudioAttributes.CONTENT_TYPE_SONIFICATION
                        )
                        .build()
                )

                isLooping = true
                prepare()
                start()
            }
        } catch (exception: Exception) {
            exception.printStackTrace()
        }
    }

    private fun startVibration() {
        stopVibration()

        try {
            vibrator =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val manager =
                        getSystemService(
                            VibratorManager::class.java
                        )

                    manager.defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    getSystemService(
                        VIBRATOR_SERVICE
                    ) as Vibrator
                }

            val pattern = longArrayOf(
                0L,
                800L,
                500L,
                800L,
                500L
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(
                    VibrationEffect.createWaveform(
                        pattern,
                        0
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(
                    pattern,
                    0
                )
            }
        } catch (exception: Exception) {
            exception.printStackTrace()
        }
    }

    private fun stopMediaPlayer() {
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }

            mediaPlayer?.release()
            mediaPlayer = null
        } catch (exception: Exception) {
            exception.printStackTrace()
            mediaPlayer = null
        }
    }

    private fun stopVibration() {
        try {
            vibrator?.cancel()
            vibrator = null
        } catch (exception: Exception) {
            exception.printStackTrace()
        }
    }

    private fun stopAlarm() {
        stopMediaPlayer()
        stopVibration()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        /*
         * Se deja vacío para evitar que el usuario cierre la alarma
         * con el botón Atrás. Debe usar Posponer o Detener.
         */
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }
}
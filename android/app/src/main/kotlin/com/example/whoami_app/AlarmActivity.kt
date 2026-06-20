package com.example.whoami_app

import android.app.Activity
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

class AlarmActivity : Activity() {

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    private var alarmId: Int = 0
    private var alarmTitle: String = "Recordatorio"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )

        alarmId = intent.getIntExtra("id", 0)
        alarmTitle = intent.getStringExtra("title") ?: "Recordatorio"

        startSound()
        startVibration()
        createView()
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
            setPadding(dp(20), dp(28), dp(20), dp(28))
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(28), dp(24), dp(28))
            background = background(
                color = Color.WHITE,
                radius = 28,
                strokeColor = Color.rgb(226, 233, 246)
            )
            elevation = dp(8).toFloat()
        }

        val screenWidth = resources.displayMetrics.widthPixels
        val cardWidth = minOf(screenWidth - dp(40), dp(430))

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

        icon.layoutParams = LinearLayout.LayoutParams(dp(86), dp(86)).apply {
            bottomMargin = dp(18)
        }

        val appTitle = TextView(this).apply {
            text = "WhoAmI?"
            textSize = 32f
            setTextColor(Color.rgb(7, 19, 31))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            includeFontPadding = false
        }

        val subtitle = TextView(this).apply {
            text = "Alarma de recordatorio"
            textSize = 18f
            setTextColor(Color.rgb(113, 121, 138))
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(20))
        }

        val reminderText = TextView(this).apply {
            text = alarmTitle
            textSize = 24f
            setTextColor(Color.rgb(25, 30, 40))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            maxLines = 3
            setPadding(0, 0, 0, dp(26))
        }

        val snoozeButton = TextView(this).apply {
            text = "Posponer 5 min"
            textSize = 17f
            setTextColor(Color.rgb(7, 19, 31))
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
                stopAlarm()
                finish()
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
        card.addView(snoozeButton)
        card.addView(stopButton)

        root.addView(card, cardParams)
        scrollView.addView(root)

        setContentView(scrollView)
    }

    private fun snoozeAlarm() {
        val fiveMinutesLater = System.currentTimeMillis() + (5 * 60 * 1000)

        AlarmScheduler.scheduleAlarm(
            context = this,
            id = alarmId,
            title = alarmTitle,
            timeMillis = fiveMinutesLater
        )

        stopAlarm()
        finish()
    }

    private fun startSound() {
        try {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@AlarmActivity, alarmUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startVibration() {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(VibratorManager::class.java)
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(VIBRATOR_SERVICE) as Vibrator
            }

            val pattern = longArrayOf(0, 800, 500, 800, 500)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAlarm() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
            vibrator?.cancel()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }
}
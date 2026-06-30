package com.example.whoami_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(
        context: Context,
        intent: Intent
    ) {
        val action = intent.action ?: return

        val supportedAction =
            action == Intent.ACTION_BOOT_COMPLETED ||
                action == Intent.ACTION_MY_PACKAGE_REPLACED ||
                action == ACTION_QUICKBOOT_POWERON ||
                action == ACTION_HTC_QUICKBOOT_POWERON

        if (!supportedAction) {
            return
        }

        val pendingResult = goAsync()
        val appContext = context.applicationContext

        Thread {
            try {
                /*
                 * En algunos teléfonos el sistema tarda unos segundos en
                 * dejar disponible AlarmManager después del arranque.
                 */
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    Thread.sleep(2_000L)
                }

                AlarmScheduler.restoreSavedAlarms(
                    appContext
                )
            } catch (exception: Exception) {
                exception.printStackTrace()
            } finally {
                Handler(Looper.getMainLooper()).post {
                    pendingResult.finish()
                }
            }
        }.start()
    }

    companion object {
        private const val ACTION_QUICKBOOT_POWERON =
            "android.intent.action.QUICKBOOT_POWERON"

        private const val ACTION_HTC_QUICKBOOT_POWERON =
            "com.htc.intent.action.QUICKBOOT_POWERON"
    }
}

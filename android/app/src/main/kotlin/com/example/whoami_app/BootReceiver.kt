package com.example.whoami_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Aquí después reprogramamos alarmas guardadas cuando se reinicie el celular.
    }
}
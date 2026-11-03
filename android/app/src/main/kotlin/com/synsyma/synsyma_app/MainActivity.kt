package com.synsyma.synsyma_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "chat_messages",
                "Chat messages",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Replies from Synsyma support" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
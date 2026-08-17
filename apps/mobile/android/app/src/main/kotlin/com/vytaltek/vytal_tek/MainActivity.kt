package com.vytaltek.vytal_tek

import com.vytaltek.vytal_tek.qring.QRingSdkHost
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        QRingSdkHost.attachChannels(
            MethodChannel(messenger, "com.vytaltek.qring/methods"),
            EventChannel(messenger, "com.vytaltek.qring/events"),
        )
    }
}

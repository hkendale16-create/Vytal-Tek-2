package com.vtk21.myapp

import com.vtk21.myapp.hband.HBandSdkHost
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Channel names kept for Flutter bridge compatibility.
        HBandSdkHost.attachChannels(
            MethodChannel(messenger, "com.vytaltek.qring/methods"),
            EventChannel(messenger, "com.vytaltek.qring/events"),
        )
    }
}

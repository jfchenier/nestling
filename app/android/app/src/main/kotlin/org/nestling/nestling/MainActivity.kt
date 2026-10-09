package org.nestling.nestling

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var timerNotifications: TimerNotifications? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val handler = TimerNotifications(this)
        timerNotifications = handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TimerNotifications.CHANNEL_NAME)
            .setMethodCallHandler(handler)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        timerNotifications?.onPermissionResult(requestCode, grantResults)
    }
}

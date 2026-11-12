package io.github.jfchenier.nestling

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var timerNotifications: TimerNotifications? = null
    private var sso: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val handler = TimerNotifications(this)
        timerNotifications = handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TimerNotifications.CHANNEL_NAME)
            .setMethodCallHandler(handler)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Push.CHANNEL_NAME)
            .setMethodCallHandler(Push.Handler(applicationContext))
        // Single sign-on coming back through io.github.jfchenier.nestling://sso (lib/sso/sso.dart):
        // the link that started the app is handed over once; later ones arrive in onNewIntent.
        sso = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SSO_CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "initialLink") {
                    result.success(ssoLink(intent))
                    intent?.data = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        ssoLink(intent)?.let { sso?.invokeMethod("link", it) }
    }

    private fun ssoLink(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return if (data.scheme == SSO_SCHEME && data.host == "sso") data.toString() else null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        timerNotifications?.onPermissionResult(requestCode, grantResults)
    }

    companion object {
        const val SSO_CHANNEL = "nestling/sso"
        const val SSO_SCHEME = "io.github.jfchenier.nestling"
    }
}

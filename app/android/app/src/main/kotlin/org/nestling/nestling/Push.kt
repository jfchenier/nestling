package org.nestling.nestling

import android.app.Application
import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Notifications from the Nestling server (Firebase Cloud Messaging), driven by lib/push.dart over
 * the `nestling/push` channel. The Firebase project is the server's: its settings come from
 * `GET /push/config` and are kept here, so the app starts Firebase itself (no google-services.json)
 * and one APK works with any server.
 */
object Push {
    const val CHANNEL_NAME = "nestling/push"
    private const val PREFS = "nestling_push"

    /** Starts Firebase with the settings saved by the last [register], if any. */
    fun start(context: Context): Boolean {
        if (FirebaseApp.getApps(context).isNotEmpty()) return true
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val appId = p.getString("app_id", null) ?: return false
        val options = FirebaseOptions.Builder()
            .setApplicationId(appId)
            .setApiKey(p.getString("api_key", "")!!)
            .setProjectId(p.getString("project_id", "")!!)
            .setGcmSenderId(p.getString("sender_id", "")!!)
            .build()
        FirebaseApp.initializeApp(context, options)
        return true
    }

    class Handler(private val context: Context) : MethodChannel.MethodCallHandler {
        override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                // Saves the server's Firebase settings, starts Firebase and answers this phone's token.
                "register" -> try {
                    val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val appId = call.argument<String>("app_id")!!
                    val started = FirebaseApp.getApps(context).firstOrNull()
                    val changed = started != null && started.options.applicationId != appId
                    p.edit()
                        .putString("app_id", appId)
                        .putString("api_key", call.argument<String>("api_key")!!)
                        .putString("project_id", call.argument<String>("project_id")!!)
                        .putString("sender_id", call.argument<String>("sender_id")!!)
                        .apply()
                    if (changed) {
                        // Another server's project: Firebase can only be set up once per run.
                        result.error("restart", "Firebase settings changed; applied on the next start", null)
                        return
                    }
                    start(context)
                    FirebaseMessaging.getInstance().token
                        .addOnSuccessListener { result.success(it) }
                        .addOnFailureListener { result.error("token", it.message, null) }
                } catch (e: Exception) {
                    result.error("firebase", e.message, null)
                }
                // Signed out: no more notifications to this phone.
                "unregister" -> {
                    if (FirebaseApp.getApps(context).isNotEmpty()) FirebaseMessaging.getInstance().deleteToken()
                    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

/** Starts Firebase before anything else, so messages can arrive while the app is closed. */
class NestlingApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            Push.start(this)
        } catch (e: Exception) {
            // Notifications from the server stay off; the app works without them.
        }
    }
}

/**
 * A timer started, changed or stopped on another phone (src/push.rs): shows or removes the same
 * running-timer notification as for this phone's own timers.
 */
class PushService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val d = message.data
        val id = d["id"]?.toIntOrNull() ?: return
        val seq = d["seq"]?.toLongOrNull() ?: 0
        // Messages can arrive out of order: keep the newest per notification.
        val prefs = getSharedPreferences("nestling_push_seq", Context.MODE_PRIVATE)
        if (seq < prefs.getLong("$id", 0)) return
        prefs.edit().putLong("$id", seq).apply()
        when (d["action"]) {
            "show" -> TimerNotice.show(
                this,
                id = id,
                title = d["title"] ?: return,
                body = d["body"] ?: "",
                running = d["running"] == "true",
                startedAt = d["started_at"]?.toLongOrNull() ?: System.currentTimeMillis(),
                chip = d["chip"]?.takeIf { it.isNotEmpty() },
            )
            "cancel" -> TimerNotice.cancel(this, id)
        }
    }

    // A new token reaches the server the next time the app opens (lib/push.dart asks for it).
    override fun onNewToken(token: String) {}
}

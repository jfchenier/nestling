package org.nestling.nestling

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Running-timer notifications (lib/timer_notifications.dart drives them over the
 * `nestling/timer_notifications` channel).
 *
 * Android 16+: a promoted ongoing notification ("Live Update"), shown as a chip in the status bar
 * with the timer counting, like a phone call. Older versions: an ongoing notification on an
 * alerting channel (silent channels hide their icon from the status bar on Pixels), with the
 * same live clock in the shade.
 */
class TimerNotifications(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val context: Context = activity.applicationContext
    private val manager = context.getSystemService(NotificationManager::class.java)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                if (Build.VERSION.SDK_INT < 33 ||
                    activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(true)
                } else {
                    // Answer once the user has chosen, so the first notification is posted after
                    // "Allow" (posted before it, Android drops it silently).
                    pendingPermission?.success(false)
                    pendingPermission = result
                    activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
                }
            }
            "show" -> {
                show(
                    id = call.argument<Int>("id")!!,
                    title = call.argument<String>("title")!!,
                    body = call.argument<String>("body")!!,
                    running = call.argument<Boolean>("running")!!,
                    // A Dart int arrives as Int or Long depending on its size.
                    startedAt = (call.argument<Number>("startedAt") ?: 0).toLong(),
                    chip = call.argument<String>("chip"),
                )
                result.success(null)
            }
            "cancel" -> {
                manager.cancel(call.argument<Int>("id")!!)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private var pendingPermission: MethodChannel.Result? = null

    /** Called by [MainActivity.onRequestPermissionsResult]. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST) return
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL) != null) return
        // Default importance keeps the icon in the status bar; no sound or vibration, and
        // onlyAlertOnce stops updates from buzzing. Promotion also needs more than "min".
        val channel = NotificationChannel(CHANNEL, "Running timers", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Shows feeds, sleeps and pumping sessions while their timer runs"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
        // The first version used a low-importance ("silent") channel; importance can't be raised
        // on an existing channel, so replace it.
        manager.deleteNotificationChannel("timers")
    }

    private fun show(id: Int, title: String, body: String, running: Boolean, startedAt: Long, chip: String?) {
        ensureChannel()
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(ACCENT)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (running) {
            // The clock counts up from the moment the time already on the timer began.
            builder.setWhen(startedAt).setShowWhen(true).setUsesChronometer(true)
        } else {
            builder.setShowWhen(false)
        }
        if (Build.VERSION.SDK_INT >= 36) {
            // Live Update: shown as a status-bar chip. Without short text the chip shows the
            // chronometer; a paused timer says so instead. The request is an extra
            // (Notification.EXTRA_REQUEST_PROMOTED_ONGOING); Builder.setRequestPromotedOngoing
            // only arrived in a later SDK.
            builder.extras.putBoolean("android.requestPromotedOngoing", true)
            if (chip != null) builder.setShortCriticalText(chip)
        }
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT < 26) builder.setPriority(Notification.PRIORITY_DEFAULT).setSound(null).setVibrate(null)
        try {
            manager.notify(id, builder.build())
        } catch (e: SecurityException) {
            // No notification permission: the timers keep working without the notification.
        }
    }

    companion object {
        const val CHANNEL_NAME = "nestling/timer_notifications"
        private const val CHANNEL = "running_timers"
        private const val PERMISSION_REQUEST = 7301
        private val ACCENT = Color.rgb(0x3D, 0x7A, 0x6A)
    }
}
